import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';
import 'base_generator.dart';

class CrudRepositoryGenerator extends BaseGenerator implements Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    for (final element in library.classes) {
      if (element.supertype == null) continue;
      final superTypeStr = element.supertype!.getDisplayString(
        withNullability: false,
      );
      if (!superTypeStr.startsWith("CrudRepository<")) continue;

      final repoInterfaceName = element.name;
      final typeArgs = element.supertype!.typeArguments;
      if (typeArgs.length < 2) continue;

      String pkType = typeArgs[1].getDisplayString(withNullability: false);
      final entityTypeName = typeArgs[0].getDisplayString(
        withNullability: false,
      );
      final entityElement =
          typeArgs[0].element as ClassElement? ??
          (throw StateError(
            'Entidade $entityTypeName não é uma classe válida',
          ));

      final tableName = getTableName(entityElement);
      final idFieldElement = findIdField(entityElement);
      final idFieldName = getPrimaryKeyName(entityElement.fields);
      final versionFieldName = getVersionFieldName(entityElement);
      final generationStrategy =
          idFieldElement != null
              ? getGeneratedValue(idFieldElement)?.strategy ??
                  GenerationType.AUTO
              : GenerationType.AUTO;

      final repoImplName = '${repoInterfaceName}Impl';

      buffer.writeln('class $repoImplName implements $repoInterfaceName {');
      buffer.writeln(
        '  dynamic get _connection => DpaConnection.instance ?? (throw StateError("DpaConnection não inicializada"));',
      );
      buffer.writeln();

      // findById
      buffer.writeln('  @override');
      buffer.writeln('  Future<$entityTypeName?> findById($pkType id) async {');
      buffer.writeln('    final results = await _connection.query(');
      buffer.writeln(
        '      "SELECT * FROM $tableName WHERE ${toSnakeCase(idFieldName)} = ?", [id]);',
      );
      buffer.writeln(
        '    return results.isNotEmpty ? $entityTypeName.fromMap(results.first) : null;',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // findAll
      buffer.writeln('  @override');
      buffer.writeln('  Future<List<$entityTypeName>> findAll() async {');
      buffer.writeln(
        '    final results = await _connection.query("SELECT * FROM $tableName") as List;',
      );
      buffer.writeln(
        '    return results.map((row) => $entityTypeName.fromMap(row)).toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // save
      buffer.writeln('  @override');
      buffer.writeln(
        '  Future<$entityTypeName> save($entityTypeName entity) async {',
      );
      buffer.writeln('    final map = entity.toMap();');
      buffer.writeln('    final pkName = "$idFieldName";');
      if (versionFieldName != null) {
        buffer.writeln('    final version = map["$versionFieldName"] ?? 0;');
        buffer.writeln('    map["$versionFieldName"] = version + 1;');
      }
      buffer.writeln('    if (entity.$idFieldName == null) {');
      buffer.writeln('      if ($generationStrategy == GenerationType.UUID) {');
      buffer.writeln('        map[pkName] = const Uuid().v4();');
      buffer.writeln(
        '      } else if ($generationStrategy == GenerationType.CUID) {',
      );
      buffer.writeln('        map[pkName] = cuid();');
      buffer.writeln('      }');
      buffer.writeln(
        '      final columns = map.keys.map(sanitizeColumnName).join(", ");',
      );
      buffer.writeln(
        '      final placeholders = map.keys.map((_) => "?").join(", ");',
      );
      buffer.writeln('      final values = map.values.toList();');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln(
        '        "INSERT INTO $tableName (\$columns) VALUES (\$placeholders)", values);',
      );
      buffer.writeln('    } else {');
      buffer.writeln('      final updateMap = Map.of(map)..remove(pkName);');
      buffer.writeln(
        '      final setClause = updateMap.keys.map((col) => "${sanitizeColumnName('col')} = ?").join(", ");',
      );
      buffer.writeln(
        '      final values = updateMap.values.toList()..add(entity.$idFieldName);',
      );
      buffer.writeln(
        '      var query = "UPDATE $tableName SET \$setClause WHERE ${toSnakeCase(idFieldName)} = ?";',
      );
      if (versionFieldName != null) {
        buffer.writeln(
          '      query += " AND ${toSnakeCase(versionFieldName)} = ?";',
        );
        buffer.writeln('      values.add(version);');
      }
      buffer.writeln(
        '      final affected = await _connection.execute(query, values);',
      );
      buffer.writeln(
        '      if (affected == 0) throw OptimisticLockException("Conflito de versionamento");',
      );
      buffer.writeln('    }');
      buffer.writeln('    return $entityTypeName.fromMap(map);');
      buffer.writeln('  }');
      buffer.writeln();

      // deleteById
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> deleteById($pkType id) async {');
      buffer.writeln('    await _connection.execute(');
      buffer.writeln(
        '      "DELETE FROM $tableName WHERE ${toSnakeCase(idFieldName)} = ?", [id]);',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // existsById
      buffer.writeln('  @override');
      buffer.writeln('  Future<bool> existsById($pkType id) async {');
      buffer.writeln('    final results = await _connection.query(');
      buffer.writeln(
        '      "SELECT 1 FROM $tableName WHERE ${toSnakeCase(idFieldName)} = ?", [id]);',
      );
      buffer.writeln('    return results.isNotEmpty;');
      buffer.writeln('  }');
      buffer.writeln();

      // count
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
}

Builder crudRepositoryGeneratorFactory(BuilderOptions options) =>
    SharedPartBuilder([CrudRepositoryGenerator()], 'crud_repository');
