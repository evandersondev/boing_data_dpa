import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

class DpaEntityGenerator extends GeneratorForAnnotation<Entity> {
  final _columnChecker = const TypeChecker.fromRuntime(Column);

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Gera apenas para classes.
    if (element is! ClassElement) return '';

    final className = element.name;
    final fields = element.fields.where((f) => !f.isStatic).toList();

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
    String fieldName = '';

    for (final field in fields) {
      final idChecker = const TypeChecker.fromRuntime(Id);
      if (idChecker.hasAnnotationOf(field)) {
        fieldName = field.name.substring(1);
        break;
      }
    }

    return "static String primaryKeyName = '$fieldName';";
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

    return 'static GenerationType primaryKeyGenerationType = $generationType;';
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

  String _generateGettersAndSetters(List<FieldElement> fields) {
    final buffer = StringBuffer();
    for (final field in fields) {
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
        .map((f) {
          // Get the display string with nullability.
          final typeStr = f.type.getDisplayString(withNullability: true);
          // If the type already ends with '?' then keep it, otherwise append '?'.
          final paramType = typeStr.endsWith('?') ? typeStr : '$typeStr?';
          return '$paramType ${f.name.substring(1)}';
        })
        .join(', ');

    final assignments = fields
        .map((f) {
          final fieldName = f.name.substring(1);
          return '..$fieldName = $fieldName ?? ${f.name}';
        })
        .join('\n');

    return '''
  $className copy({$parameters}) {
    return $className()
      $assignments;
  }
''';
  }

  String _generateFromMapMethod(String className, List<FieldElement> fields) {
    final assignments = fields
        .map((f) {
          return '..${f.name.substring(1)} = ${_formatFromMap(f)}';
        })
        .join('\n');

    return '''
  $className fromMap(Map<String, dynamic> map) {
    return $className()
      $assignments;
  }
''';
  }

  String _generateToMapMethod(String className, List<FieldElement> fields) {
    final mapEntries = fields
        .map((f) {
          if (f.type.getDisplayString(withNullability: false).endsWith('?')) {
            return '''
      if (${f.name.substring(1)} != null) {
        map.addAll({'${_toSnakeCase(f.name.substring(1))}': ${_formatToMap(f)} });
      }
''';
          }

          return '''map.addAll({'${_toSnakeCase(f.name.substring(1))}': ${_formatToMap(f)} });''';
        })
        .join('\n');

    return '''
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    $mapEntries

    return map;
  }
''';
  }

  /// Converte um nome de variável/campo para snake_case.
  String _toSnakeCase(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      if (i > 0 && input[i].toUpperCase() == input[i]) {
        buffer.write('_');
      }
      buffer.write(input[i].toLowerCase());
    }
    return buffer.toString();
  }

  /// Obtém o nome da coluna definido pela annotation [Column] se presente,
  /// caso contrário utiliza o nome do campo convertido para snake_case.
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
    return _toSnakeCase(field.name);
  }

  /// Retorna apenas a expressão de conversão para extrair o valor do mapa
  /// para o campo, utilizando a chave definida via annotation [Column] ou snake_case.
  String _formatFromMap(FieldElement field) {
    final key = '"${_getColumnName(field).substring(1)}"';
    if (field.type.isDartCoreInt) {
      return 'map[$key] as int';
    } else if (field.type.isDartCoreDouble) {
      return 'map[$key] as double';
    } else if (field.type.isDartCoreBool) {
      return '(map[$key] as int) == 1';
    } else if (field.type.getDisplayString(withNullability: false) ==
        'DateTime') {
      return 'DateTime.parse("\${map[$key]}")';
    }
    return 'map[$key]';
  }

  /// Retorna apenas a expressão de conversão para inserir o valor do campo no mapa.
  String _formatToMap(FieldElement field) {
    if (field.type.isDartCoreInt ||
        field.type.isDartCoreDouble ||
        field.type.isDartCoreString) {
      return field.name.substring(1);
    } else if (field.type.isDartCoreBool) {
      return '${field.name.substring(1)} ? 1 : 0';
    } else if (field.type.getDisplayString(withNullability: false) ==
        'DateTime') {
      // Verifica se há annotation Temporal para definir a formatação.
      final temporalType = _getTemporalAnnotation(field);
      if (temporalType == 'DATE') {
        return '${field.name.substring(1)}.toIso8601String().split("T")[0]';
      } else if (temporalType == 'TIME') {
        return '${field.name.substring(1)}.toIso8601String().split("T")[1]';
      }
      return '${field.name.substring(1)}.toIso8601String()';
    }
    return field.name.substring(1);
  }

  /// Verifica se o campo possui a annotation Temporal e retorna o seu tipo (DATE, TIME, etc).
  String? _getTemporalAnnotation(FieldElement field) {
    for (final meta in field.metadata) {
      final constantValue = meta.computeConstantValue();
      if (constantValue != null &&
          constantValue.type?.getDisplayString(withNullability: false) ==
              'Temporal') {
        return constantValue.getField('type')?.toStringValue();
      }
    }
    return null;
  }
}

Builder dpaEntityGeneratorFactory(BuilderOptions options) {
  return SharedPartBuilder([DpaEntityGenerator()], 'entity');
}
