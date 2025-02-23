import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

class DpaRepositoryGenerator extends Generator {
  final TypeChecker _tableChecker = const TypeChecker.fromRuntime(Table);

  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    // Iterate over all classes in the library.
    for (final element in library.classes) {
      // Only process classes extending DpaRepository<T, ID>
      if (element.supertype == null) continue;
      final superTypeStr = element.supertype!.getDisplayString(
        withNullability: false,
      );
      if (!superTypeStr.startsWith("DpaRepository<")) continue;

      final repoInterfaceName = element.name;
      final typeArgs = element.supertype!.typeArguments;
      if (typeArgs.length < 2) continue;

      // pkType from type argument (will be overridden if primary key field is found)
      String pkType = typeArgs[1].getDisplayString(withNullability: false);
      final entityTypeName = typeArgs[0].getDisplayString(
        withNullability: false,
      );

      // Determine table name based on @Table annotation on entity.
      String tableName;
      final entityElement = typeArgs[0].element;
      if (entityElement is! ClassElement) {
        throw Exception("The type $entityTypeName is not a valid class.");
      }

      final tableAnnotation = _tableChecker.firstAnnotationOf(
        entityElement,
        throwOnUnresolved: false,
      );
      if (tableAnnotation != null) {
        final nameField = tableAnnotation.getField('name');
        final nameValue = nameField?.toStringValue();
        tableName =
            (nameValue != null && nameValue.isNotEmpty)
                ? nameValue
                : entityTypeName.toLowerCase();
      } else {
        tableName = entityTypeName.toLowerCase();
      }

      // Find the primary key field by looking for the @Id annotation.
      final FieldElement? idFieldElement = _findIdField(entityElement);
      // Get primary key name from the generated extension (assumes format: <propertyName> without underscore)
      String? idFieldName = _getPrimaryKeyName(entityElement.fields);
      GenerationType? generationStrategy = GenerationType.AUTO;
      if (idFieldElement != null) {
        final genValue = _getGeneratedValue(idFieldElement);
        if (genValue != null) {
          generationStrategy = genValue.strategy;
        }
      }

      // The implementation class name is the repository interface name + "Impl"
      final repoImplName = '${repoInterfaceName}Impl';

      buffer.writeln('class $repoImplName implements $repoInterfaceName {');
      buffer.writeln('  dynamic get _connection => DpaConnection.instance;');
      buffer.writeln();

      // findById method
      buffer.writeln('  @override');
      buffer.writeln('  Future<$entityTypeName?> findById($pkType id) async {');
      buffer.writeln(
        '    final results = await _connection.query("SELECT * FROM $tableName WHERE ${_toSnakeCase(idFieldName)} = ?", [id]);',
      );
      buffer.writeln(
        '    return results.isNotEmpty ? $entityTypeName().fromMap(results.first) : null;',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // findAll method
      buffer.writeln('  @override');
      buffer.writeln('  Future<List<$entityTypeName>> findAll() async {');
      buffer.writeln(
        '    final results = await _connection.query("SELECT * FROM $tableName") as List;',
      );
      buffer.writeln(
        '    return results.isNotEmpty ? results.toList().map((row) => $entityTypeName().fromMap(row)).toList() : [];',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // save method
      // This method uses the entity's generated extension to check the primary key.
      // It uses ${entityTypeName}Generated.primaryKeyName and ${entityTypeName}Generated.primaryKeyGenerationType.
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> save($entityTypeName entity) async {');
      buffer.writeln(
        '    // Retrieve generation type from the generated extension',
      );
      buffer.writeln(
        '    final generationType = ${entityTypeName}Generated.primaryKeyGenerationType;',
      );
      buffer.writeln();
      buffer.writeln(
        '    // Check if the primary key is null using the getter',
      );
      buffer.writeln('    if (entity.$idFieldName == null) {');
      buffer.writeln(
        '      // Generate primary key based on generation strategy',
      );
      buffer.writeln('      if (generationType == GenerationType.UUID) {');
      buffer.writeln(
        '        entity = entity.copy($idFieldName: Uuid().v4());',
      );
      buffer.writeln(
        '      } else if (generationType == GenerationType.CUID) {',
      );
      buffer.writeln('        entity = entity.copy($idFieldName: cuid());');
      buffer.writeln(
        '      } else if (generationType == GenerationType.AUTO) {',
      );
      buffer.writeln('        entity = entity.copy($idFieldName: null);');
      buffer.writeln('      }');
      buffer.writeln();
      buffer.writeln('      // Insert new entity');
      buffer.writeln('      final map = entity.toMap();');
      buffer.writeln('      final columns = map.keys.join(\', \');');
      buffer.writeln(
        '      final placeholders = map.keys.map((_) => \'?\').join(\', \');',
      );
      buffer.writeln('      final values = map.values.toList();');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln(
        '        "INSERT INTO $tableName (\$columns) VALUES (\$placeholders)",',
      );
      buffer.writeln('        values');
      buffer.writeln('      );');
      buffer.writeln('    } else {');
      buffer.writeln('      // Update existing entity');
      buffer.writeln('      final map = entity.toMap();');
      buffer.writeln(
        '      final pkName = ${entityTypeName}Generated.primaryKeyName;',
      );
      buffer.writeln('      // Remove the primary key from the update set');
      buffer.writeln('      final updateMap = Map.of(map)..remove(pkName);');
      buffer.writeln(
        '      final setClause = updateMap.keys.map((col) => "\$col = ?").join(\', \');',
      );
      buffer.writeln('      final values = updateMap.values.toList();');
      buffer.writeln('      values.add(entity.$idFieldName);');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln(
        '        "UPDATE $tableName SET \$setClause WHERE \$pkName = ?",',
      );
      buffer.writeln('        values');
      buffer.writeln('      );');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();

      // saveAll method
      buffer.writeln('  @override');
      buffer.writeln(
        '  Future<void> saveAll(List<$entityTypeName> entities) async {',
      );
      buffer.writeln('    for (final entity in entities) {');
      buffer.writeln('      await save(entity);');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();

      // deleteById method
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> deleteById($pkType id) async {');
      buffer.writeln(
        '    await _connection.execute("DELETE FROM $tableName WHERE ${idFieldName != null ? _toSnakeCase(idFieldName) : "id"} = ?", [id]);',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // deleteAll method
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> deleteAll() async {');
      buffer.writeln(
        '    await _connection.execute("DELETE FROM $tableName");',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // count method
      buffer.writeln('  @override');
      buffer.writeln('  Future<int> count() async {');
      buffer.writeln(
        '    final result = await _connection.query("SELECT COUNT(*) as count FROM $tableName");',
      );
      buffer.writeln(
        '    return result.isNotEmpty ? result.first["count"] as int : 0;',
      );
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Finds the field annotated with @Id in the given entity.
  FieldElement? _findIdField(ClassElement entityElement) {
    for (final field in entityElement.fields) {
      final annotation = const TypeChecker.fromRuntime(
        Id,
      ).firstAnnotationOf(field, throwOnUnresolved: false);
      if (annotation != null) {
        return field;
      }
    }
    return null;
  }

  String _getPrimaryKeyName(List<FieldElement> fields) {
    String fieldName = '';
    for (final field in fields) {
      final idChecker = const TypeChecker.fromRuntime(Id);
      if (idChecker.hasAnnotationOf(field)) {
        // Remove leading underscore if present.
        fieldName =
            field.name.startsWith('_') ? field.name.substring(1) : field.name;
        break;
      }
    }
    return fieldName;
  }

  /// Retrieves the GeneratedValue annotation from the field, if present.
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

  /// Converts a camelCase identifier to snake_case.
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
}

Builder dpaRepositoryGeneratorFactory(BuilderOptions options) =>
    SharedPartBuilder([DpaRepositoryGenerator()], 'repository');
