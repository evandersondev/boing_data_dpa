import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

class DpaMigrationGenerator extends GeneratorForAnnotation<Entity> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader entityAnnotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) return '';

    final className = element.name;
    final tableName = _getTableName(element, className);
    final fields = element.fields.where((f) => !f.isStatic).toList();

    final columnDefinitions = fields.map(_generateColumnDefinition).join(',\n');
    final createTableSQL =
        'CREATE TABLE IF NOT EXISTS $tableName (\n$columnDefinitions\n);';
    _writeToMigrationFile(createTableSQL, tableName);

    return '';
  }

  String _getTableName(ClassElement element, String className) {
    final tableChecker = const TypeChecker.fromRuntime(Table);
    final tableAnnotation = tableChecker.firstAnnotationOf(
      element,
      throwOnUnresolved: false,
    );
    if (tableAnnotation != null) {
      final nameField = tableAnnotation.getField('name');
      final tableName = nameField?.toStringValue();
      if (tableName != null && tableName.isNotEmpty) {
        return tableName;
      }
    }
    return className.toLowerCase();
  }

  String _generateColumnDefinition(FieldElement field) {
    final columnName = _removeLeadingUnderscore(_toSnakeCase(field.name));
    final idChecker = const TypeChecker.fromRuntime(Id);
    if (idChecker.hasAnnotationOf(field)) {
      final generatedValue = _getGeneratedValue(field);
      if (generatedValue != null) {
        switch (generatedValue.strategy) {
          case GenerationType.AUTO:
            return '$columnName INTEGER PRIMARY KEY AUTOINCREMENT';
          case GenerationType.UUID:
          case GenerationType.CUID:
            return '$columnName TEXT PRIMARY KEY';
        }
      }
      return '$columnName INTEGER PRIMARY KEY';
    }

    final columnChecker = const TypeChecker.fromRuntime(Column);
    final columnAnnotation = columnChecker.firstAnnotationOf(
      field,
      throwOnUnresolved: false,
    );
    String? customDefinition;
    bool isUnique = false;
    if (columnAnnotation != null) {
      final definitionField = columnAnnotation.getField('columnDefinition');
      customDefinition = definitionField?.toStringValue();
      final uniqueField = columnAnnotation.getField('unique');
      isUnique = uniqueField?.toBoolValue() ?? false;
    }

    String columnType;
    if (customDefinition != null && customDefinition.isNotEmpty) {
      columnType = customDefinition;
    } else {
      columnType = _getColumnType(field);
    }

    final uniqueConstraint = isUnique ? ' UNIQUE' : '';
    final nullConstraint =
        field.type.nullabilitySuffix == NullabilitySuffix.question
            ? 'NULL'
            : 'NOT NULL';

    return '$columnName $columnType$uniqueConstraint $nullConstraint';
  }

  String _getColumnType(FieldElement field) {
    final temporalChecker = const TypeChecker.fromRuntime(Temporal);
    final temporalAnnotation = temporalChecker.firstAnnotationOf(
      field,
      throwOnUnresolved: false,
    );
    if (temporalAnnotation != null) {
      return 'TEXT';
    }

    if (field.type.isDartCoreInt) {
      return 'INTEGER';
    } else if (field.type.isDartCoreDouble) {
      return 'REAL';
    } else if (field.type.isDartCoreString) {
      return 'TEXT';
    } else if (field.type.isDartCoreBool) {
      return 'INTEGER';
    } else if (field.type.getDisplayString(withNullability: false) ==
        'DateTime') {
      return 'TEXT';
    } else {
      return 'TEXT';
    }
  }

  String _toSnakeCase(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      if (i > 0 &&
          input[i].toUpperCase() == input[i] &&
          input[i] != '_' &&
          !RegExp(r'[0-9]').hasMatch(input[i])) {
        buffer.write('_');
      }
      buffer.write(input[i].toLowerCase());
    }
    return buffer.toString();
  }

  String _removeLeadingUnderscore(String input) {
    if (input.startsWith('_')) {
      return input.substring(1);
    }
    return input;
  }

  GeneratedValue? _getGeneratedValue(FieldElement field) {
    final annotation = const TypeChecker.fromRuntime(
      GeneratedValue,
    ).firstAnnotationOf(field, throwOnUnresolved: false);
    if (annotation != null) {
      final strategyField = annotation.getField('strategy');
      if (strategyField != null) {
        final index = strategyField.getField('index')?.toIntValue();
        if (index != null && index < GenerationType.values.length) {
          return GeneratedValue(strategy: GenerationType.values[index]);
        }
      }
      return GeneratedValue();
    }
    return null;
  }

  void _writeToMigrationFile(String sql, String tableName) {
    final directory = Directory('database');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final file = File('${directory.path}/migration.sql');

    if (file.existsSync()) {
      final content = file.readAsStringSync();
      if (content.contains(
        RegExp(r'CREATE TABLE IF NOT EXISTS\s+' + tableName),
      )) {
        print(
          '⚠️ Tabela "$tableName" já existe no arquivo de migração. Pulando...',
        );
        return;
      }
    }

    file.writeAsStringSync(
      '/* Create table $tableName */\n$sql\n',
      mode: FileMode.append,
    );
    print('✅ Migração escrita no arquivo database/migration.sql');
  }
}

Builder dpaMigrationGeneratorFactory(BuilderOptions options) {
  return SharedPartBuilder([DpaMigrationGenerator()], 'migration');
}
