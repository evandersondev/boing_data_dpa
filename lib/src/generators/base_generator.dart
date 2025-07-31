import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

abstract class BaseGenerator {
  final TypeChecker tableChecker = const TypeChecker.fromRuntime(Table);
  final TypeChecker idChecker = const TypeChecker.fromRuntime(Id);
  final TypeChecker columnChecker = const TypeChecker.fromRuntime(Column);
  final TypeChecker generatedValueChecker = const TypeChecker.fromRuntime(
    GeneratedValue,
  );
  final TypeChecker oneToManyChecker = const TypeChecker.fromRuntime(OneToMany);
  final TypeChecker manyToOneChecker = const TypeChecker.fromRuntime(ManyToOne);
  final TypeChecker versionChecker = const TypeChecker.fromRuntime(Version);

  String sanitizeColumnName(String name) {
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) {
      throw FormatException('Nome de coluna inválido: $name');
    }
    return name;
  }

  String toSnakeCase(String input) {
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

  FieldElement? findIdField(ClassElement entityElement) {
    for (final field in entityElement.fields) {
      if (idChecker.hasAnnotationOf(field)) {
        return field;
      }
    }
    throw StateError(
      'Nenhum campo com @Id encontrado em ${entityElement.name}',
    );
  }

  String getPrimaryKeyName(List<FieldElement> fields) {
    for (final field in fields) {
      if (idChecker.hasAnnotationOf(field)) {
        return field.name.startsWith('_')
            ? field.name.substring(1)
            : field.name;
      }
    }
    throw StateError('Nenhum campo com @Id encontrado');
  }

  GeneratedValue? getGeneratedValue(FieldElement field) {
    final annotation = generatedValueChecker.firstAnnotationOf(field);
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

  String getTableName(ClassElement entityElement) {
    final tableAnnotation = tableChecker.firstAnnotationOf(entityElement);
    if (tableAnnotation != null) {
      final nameField = tableAnnotation.getField('name');
      final nameValue = nameField?.toStringValue();
      return (nameValue != null && nameValue.isNotEmpty)
          ? nameValue
          : entityElement.name.toLowerCase();
    }
    return entityElement.name.toLowerCase();
  }

  String? getVersionFieldName(ClassElement entityElement) {
    for (final field in entityElement.fields) {
      if (versionChecker.hasAnnotationOf(field)) {
        return field.name.startsWith('_')
            ? field.name.substring(1)
            : field.name;
      }
    }
    return null;
  }
}
