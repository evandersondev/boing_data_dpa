import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

class DpaEntityGenerator extends GeneratorForAnnotation<Entity> {
  final _columnChecker = const TypeChecker.fromRuntime(Column);
  final _temporalChecker = const TypeChecker.fromRuntime(Temporal);
  final _transientChecker = const TypeChecker.fromRuntime(Transient);

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) return '';

    final className = element.name;
    final fields = element.fields.where((f) => !f.isStatic).toList();

    // Verifica se existe um campo com @Id
    if (!fields.any(
      (f) => const TypeChecker.fromRuntime(Id).hasAnnotationOf(f),
    )) {
      throw StateError(
        'A entidade $className deve ter pelo menos um campo anotado com @Id',
      );
    }

    // Verifica se existe um construtor padrão
    if (!element.constructors.any(
      (c) => c.name.isEmpty && c.parameters.isEmpty,
    )) {
      throw StateError(
        'A entidade $className deve ter um construtor padrão sem parâmetros',
      );
    }

    final primaryKeyName = _getPrimaryKeyName(fields);
    final primaryKeyGenerationType = _getPrimaryKeyGenerationType(fields);
    final gettersAndSetters = _generateGettersAndSetters(fields);
    final copyMethod = _generateCopyMethod(className, fields);
    final fromMapMethod = _generateFromMapMethod(className, fields);
    final toMapMethod = _generateToMapMethod(className, fields);

    return '''
extension ${className}Generated on $className {
$primaryKeyName
$primaryKeyGenerationType

$gettersAndSetters

$copyMethod

$toMapMethod

$fromMapMethod
}
''';
  }

  String _getPrimaryKeyName(List<FieldElement> fields) {
    for (final field in fields) {
      final idChecker = const TypeChecker.fromRuntime(Id);
      if (idChecker.hasAnnotationOf(field)) {
        final fieldName =
            field.name.startsWith('_') ? field.name.substring(1) : field.name;
        return "static String primaryKeyName = '$fieldName';";
      }
    }
    return '';
  }

  String _getPrimaryKeyGenerationType(List<FieldElement> fields) {
    GenerationType generationType = GenerationType.AUTO;

    for (final field in fields) {
      final idChecker = const TypeChecker.fromRuntime(Id);
      if (idChecker.hasAnnotationOf(field)) {
        final generatedValue = _getGeneratedValue(field);
        if (generatedValue != null) {
          generationType = generatedValue.strategy;
        }
        break;
      }
    }

    return 'static GenerationType primaryKeyGenerationType = GenerationType.$generationType;';
  }

  GeneratedValue? _getGeneratedValue(FieldElement field) {
    final annotation = const TypeChecker.fromRuntime(
      GeneratedValue,
    ).firstAnnotationOf(field, throwOnUnresolved: false);
    if (annotation != null) {
      final strategyField = annotation.getField('strategy');
      final index = strategyField?.getField('index')?.toIntValue();
      if (index != null && index < GenerationType.values.length) {
        return GeneratedValue(strategy: GenerationType.values[index]);
      }
      return GeneratedValue();
    }
    return null;
  }

  String _generateGettersAndSetters(List<FieldElement> fields) {
    final buffer = StringBuffer();
    for (final field in fields) {
      if (_transientChecker.hasAnnotationOf(field)) continue;
      final fieldName = field.name;
      final getterName =
          fieldName.startsWith('_') ? fieldName.substring(1) : fieldName;
      buffer.writeln(
        '  ${field.type.getDisplayString(withNullability: true)} get $getterName => $fieldName;',
      );
      buffer.writeln(
        '  set $getterName(${field.type.getDisplayString(withNullability: true)} $getterName) => $fieldName = $getterName;',
      );
    }
    return buffer.toString();
  }

  String _generateCopyMethod(String className, List<FieldElement> fields) {
    final parameters = fields
        .where((f) => !_transientChecker.hasAnnotationOf(f))
        .map((f) {
          final typeStr = f.type.getDisplayString(withNullability: true);
          final paramType = typeStr.endsWith('?') ? typeStr : '$typeStr?';
          return '$paramType ${f.name.startsWith('_') ? f.name.substring(1) : f.name}';
        })
        .join(', ');

    final assignments = fields
        .where((f) => !_transientChecker.hasAnnotationOf(f))
        .map((f) {
          final fieldName =
              f.name.startsWith('_') ? f.name.substring(1) : f.name;
          return '..$fieldName = $fieldName ?? ${f.name}';
        })
        .join('\n      ');

    return '''
  $className copy({$parameters}) {
    return $className()
      $assignments;
  }
''';
  }

  String _generateFromMapMethod(String className, List<FieldElement> fields) {
    final assignments = fields
        .where((f) => !_transientChecker.hasAnnotationOf(f))
        .map((f) {
          final fieldName =
              f.name.startsWith('_') ? f.name.substring(1) : f.name;
          return '..$fieldName = ${_formatFromMap(f)}';
        })
        .join('\n      ');

    return '''
  $className fromMap(Map<String, dynamic> map) {
    return $className()
      $assignments;
  }
''';
  }

  String _generateToMapMethod(String className, List<FieldElement> fields) {
    final mapEntries = fields
        .where((f) => !_transientChecker.hasAnnotationOf(f))
        .map((f) {
          final columnName = _getColumnName(f);
          final fieldName =
              f.name.startsWith('_') ? f.name.substring(1) : f.name;
          if (f.type.getDisplayString(withNullability: true).endsWith('?')) {
            return '''
    if ($fieldName != null) {
      map['$columnName'] = ${_formatToMap(f)};
    }
''';
          }
          return '''map['$columnName'] = ${_formatToMap(f)};''';
        })
        .join('\n    ');

    return '''
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    $mapEntries
    return map;
  }
''';
  }

  String _toSnakeCase(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 &&
          char.toUpperCase() == char &&
          char != '_' &&
          !RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  String _getColumnName(FieldElement field) {
    final columnAnnotation = _columnChecker.firstAnnotationOf(
      field,
      throwOnUnresolved: false,
    );
    if (columnAnnotation != null) {
      final nameField = columnAnnotation.getField('name');
      final nameValue = nameField?.toStringValue();
      if (nameValue != null && nameValue.isNotEmpty) {
        return nameValue;
      }
    }
    return _toSnakeCase(
      field.name.startsWith('_') ? field.name.substring(1) : field.name,
    );
  }

  String _formatFromMap(FieldElement field) {
    final columnName = _getColumnName(field);
    final type = field.type.getDisplayString(withNullability: false);
    if (field.type.isDartCoreInt) {
      return 'map["$columnName"] as int?';
    } else if (field.type.isDartCoreDouble) {
      return 'map["$columnName"] as double?';
    } else if (field.type.isDartCoreBool) {
      return 'map["$columnName"] == 1';
    } else if (type == 'DateTime') {
      return 'map["$columnName"] != null ? DateTime.tryParse(map["$columnName"] as String) : null';
    }
    return 'map["$columnName"] as ${field.type.getDisplayString(withNullability: true)}';
  }

  String _formatToMap(FieldElement field) {
    final fieldName =
        field.name.startsWith('_') ? field.name.substring(1) : field.name;
    final type = field.type.getDisplayString(withNullability: false);
    if (field.type.isDartCoreInt ||
        field.type.isDartCoreDouble ||
        field.type.isDartCoreString) {
      return fieldName;
    } else if (field.type.isDartCoreBool) {
      return '$fieldName ? 1 : 0';
    } else if (type == 'DateTime') {
      final temporalType = _getTemporalAnnotation(field)?.type;
      if (temporalType == TemporalType.DATE) {
        return '$fieldName?.toIso8601String().split("T")[0]';
      } else if (temporalType == TemporalType.TIME) {
        return '$fieldName?.toIso8601String().split("T")[1].split(".")[0]';
      }
      return '$fieldName?.toIso8601String()';
    }
    return fieldName;
  }

  Temporal? _getTemporalAnnotation(FieldElement field) {
    final annotation = _temporalChecker.firstAnnotationOf(
      field,
      throwOnUnresolved: false,
    );
    if (annotation != null) {
      final typeField = annotation.getField('type');
      final index = typeField?.getField('index')?.toIntValue();
      if (index != null && index < TemporalType.values.length) {
        return Temporal(TemporalType.values[index]);
      }
    }
    return null;
  }
}

Builder dpaEntityGeneratorFactory(BuilderOptions options) {
  return SharedPartBuilder([DpaEntityGenerator()], 'entity');
}
