import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'base_generator.dart';
import 'crud_repository_generator.dart';

class PagingAndSortingRepositoryGenerator extends BaseGenerator
    implements Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    for (final element in library.classes) {
      if (element.supertype == null) continue;
      final superTypeStr = element.supertype!.getDisplayString(
        withNullability: false,
      );
      if (!superTypeStr.startsWith("PagingAndSortingRepository<")) continue;

      final repoInterfaceName = element.name;
      final typeArgs = element.supertype!.typeArguments;
      if (typeArgs.length < 2) continue;

      final entityTypeName = typeArgs[0].getDisplayString(
        withNullability: false,
      );
      final entityElement =
          typeArgs[0].element as ClassElement? ??
          (throw StateError(
            'Entidade $entityTypeName não é uma classe válida',
          ));

      final tableName = getTableName(entityElement);

      final repoImplName = '${repoInterfaceName}Impl';

      buffer.writeln(
        'class $repoImplName extends ${CrudRepositoryGenerator().generate(library, buildStep).split('class')[1].split('}')[0]} implements $repoInterfaceName {',
      );
      buffer.writeln(
        '  dynamic get _connection => DpaConnection.instance ?? (throw StateError("DpaConnection não inicializada"));',
      );
      buffer.writeln();

      // findAllPaged
      buffer.writeln('  @override');
      buffer.writeln(
        '  Future<Page<$entityTypeName>> findAllPaged({required int page, required int size}) async {',
      );
      buffer.writeln(
        '    if (page < 0 || size <= 0) throw ArgumentError("Page deve ser >= 0 e size > 0");',
      );
      buffer.writeln('    final offset = page * size;');
      buffer.writeln('    final results = await _connection.query(');
      buffer.writeln(
        '      "SELECT * FROM $tableName LIMIT ? OFFSET ?", [size, offset]);',
      );
      buffer.writeln(
        '    final countResult = await _connection.query("SELECT COUNT(*) as count FROM $tableName");',
      );
      buffer.writeln(
        '    final totalElements = countResult.first["count"] as int;',
      );
      buffer.writeln('    final totalPages = (totalElements / size).ceil();');
      buffer.writeln(
        '    final content = results.map((row) => $entityTypeName.fromMap(row)).toList();',
      );
      buffer.writeln('    return Page(content, totalElements, totalPages);');
      buffer.writeln('  }');
      buffer.writeln();

      // findAllSorted
      buffer.writeln('  @override');
      buffer.writeln(
        '  Future<List<$entityTypeName>> findAllSorted(Comparator<$entityTypeName> comparator) async {',
      );
      buffer.writeln(
        '    final results = await _connection.query("SELECT * FROM $tableName") as List;',
      );
      buffer.writeln(
        '    final entities = results.map((row) => $entityTypeName.fromMap(row)).toList();',
      );
      buffer.writeln('    entities.sort(comparator);');
      buffer.writeln('    return entities;');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    }
    return buffer.toString();
  }
}

Builder pagingAndSortingRepositoryGeneratorFactory(BuilderOptions options) =>
    SharedPartBuilder([
      PagingAndSortingRepositoryGenerator(),
    ], 'paging_and_sorting_repository');
