import 'dart:io';

import 'package:boing_data_dpa/src/orm/application_config.dart';

import '../boing_data_dpa.dart';

/// Classe responsável por inicializar o banco de dados e rodar as migrações automaticamente.
class DpaInitializer {
  final DbConnection database; // Pode ser SQLite, MySQL ou PostgreSQL

  DpaInitializer(this.database);

  /// Inicializa o banco de dados e executa as migrações ao rodar a API.
  /// Para SQLite, garante que o arquivo "database/database.db" exista, que é a conexão esperada.
  /// Para MySQL e PostgreSQL, apenas executa as migrações do arquivo migration.sql.
  Future<void> initialize() async {
    // Recupera as configurações da aplicação.
    final config = await ApplicationConfig.load();
    final scheme = config.databaseUri.scheme;

    if (scheme == 'sqlite') {
      // Para SQLite, garante que o arquivo database.db exista
      final dbFile = File('database/database.db');
      if (!dbFile.existsSync()) {
        print('Criando o arquivo database.db para SQLite...');
        // Cria o diretório "database" se não existir
        final dbDir = Directory('database');
        if (!dbDir.existsSync()) {
          dbDir.createSync(recursive: true);
        }
        // Cria o arquivo database.db vazio; o conteúdo será manipulado pelas migrações
        dbFile.createSync();
      }
    } else {
      // Para MySQL ou PostgreSQL, não é necessário criar nenhum arquivo.
      print(
        'Conectado ao banco ${scheme.toUpperCase()}. Executando migrações...',
      );
    }

    // Lê o arquivo de migrações gerado pelo build_runner.
    final migrationFile = File('database/migration.sql');
    if (!migrationFile.existsSync()) {
      throw Exception('Arquivo migration.sql não encontrado em database/.');
    }

    print('Lendo e executando migrações do arquivo migration.sql...');
    final content = await migrationFile.readAsString();

    // Divide os comandos SQL pelo ponto e vírgula, removendo espaços em branco e filtros.
    final sqlCommands =
        content
            .split(';')
            .map((cmd) => cmd.trim())
            .where((cmd) => cmd.isNotEmpty)
            .toList();

    // Executa cada comando SQL na conexão do banco de dados.
    for (final sql in sqlCommands) {
      database.execute(sql);
    }

    print('Migrações concluídas com sucesso!');
  }
}
