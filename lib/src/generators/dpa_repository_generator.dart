import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'base_generator.dart';
import 'paging_and_sorting_repository_generator.dart';

class JpaRepositoryGenerator extends BaseGenerator implements Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    for (final element in library.classes) {
      if (element.supertype == null) continue;
      final superTypeStr = element.supertype!.getDisplayString(
        withNullability: false,
      );
      if (!superTypeStr.startsWith("JpaRepository<")) continue;

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
      final idFieldName = getPrimaryKeyName(entityElement.fields);

      final repoImplName = '${repoInterfaceName}Impl';

      buffer.writeln(
        'class $repoImplName extends ${PagingAndSortingRepositoryGenerator().generate(library, buildStep).split('class')[1].split('}')[0]} implements $repoInterfaceName {',
      );
      buffer.writeln(
        '  dynamic get _connection => DpaConnection.instance ?? (throw StateError("DpaConnection não inicializada"));',
      );
      buffer.writeln();

      // flush
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> flush() async {');
      buffer.writeln(
        '    // No-op para banco de dados que não requerem flush explícito',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // saveAll
      buffer.writeln('  @override');
      buffer.writeln(
        '  Future<List<$entityTypeName>> saveAll(List<$entityTypeName> entities) async {',
      );
      buffer.writeln('    if (entities.isEmpty) return [];');
      buffer.writeln('    final results = <Map<String, dynamic>>[];');
      buffer.writeln(
        '    final newEntities = entities.where((e) => e.$idFieldName == null).toList();',
      );
      buffer.writeln('    if (newEntities.isNotEmpty) {');
      buffer.writeln('      final map = newEntities.first.toMap();');
      buffer.writeln(
        '      final columns = map.keys.map(sanitizeColumnName).join(", ");',
      );
      buffer.writeln(
        '      final placeholders = map.keys.map((_) => "?").join(", ");',
      );
      buffer.writeln(
        '      final values = newEntities.map((e) => e.toMap().values.toList()).expand((v) => v).toList();',
      );
      buffer.writeln('      await _connection.execute(');
      buffer.writeln(
        '        "INSERT INTO $tableName (\$columns) VALUES (\$placeholders)", values);',
      );
      buffer.writeln(
        '      results.addAll(newEntities.map((e) => e.toMap()));',
      );
      buffer.writeln('    }');
      buffer.writeln(
        '    for (final entity in entities.where((e) => e.$idFieldName != null)) {',
      );
      buffer.writeln('      await save(entity);');
      buffer.writeln('      results.add(entity.toMap());');
      buffer.writeln('    }');
      buffer.writeln(
        '    return results.map((map) => $entityTypeName.fromMap(map)).toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // deleteAll
      buffer.writeln('  @override');
      buffer.writeln('  Future<void> deleteAll() async {');
      buffer.writeln(
        '    await _connection.execute("DELETE FROM $tableName");',
      );
      buffer.writeln('  }');
      buffer.writeln();

      // Suporte a relacionamentos OneToMany
      for (final field in entityElement.fields) {
        final oneToMany = oneToManyChecker.firstAnnotationOf(field);
        if (oneToMany != null) {
          final mappedBy =
              oneToMany.getField('mappedBy')?.toStringValue() ?? '';
          final relatedType = field.type
              .getDisplayString(withNullability: false)
              .replaceAll('List<', '')
              .replaceAll('>', '');
          buffer.writeln(
            '  Future<List<$relatedType>> find${field.name.capitalize()}($pkType id) async {',
          );
          buffer.writeln('    final results = await _connection.query(');
          buffer.writeln(
            '      "SELECT * FROM ${relatedType.toLowerCase()} WHERE ${toSnakeCase(mappedBy)} = ?", [id]);',
          );
          buffer.writeln(
            '    return results.map((row) => $relatedType.fromMap(row)).toList();',
          );
          buffer.writeln('  }');
        }
      }

      buffer.writeln('}');
      buffer.writeln();
    }
    return buffer.toString();
  }
}

Builder jpaRepositoryGeneratorFactory(BuilderOptions options) =>
    SharedPartBuilder([JpaRepositoryGenerator()], 'jpa_repository');

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
