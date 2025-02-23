import 'dart:io';

import 'package:boing_data_dpa/src/orm/application_config.dart';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:postgres/postgres.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Define a common interface for database connections.
abstract class DbConnection {
  /// Executes a query that returns results.
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? parameters,
  ]);

  /// Executes a statement without returning results.
  Future<void> execute(String sql, [List<dynamic>? parameters]);
}

/// SQLite connection wrapper.
class SqliteConnectionWrapper implements DbConnection {
  final sqlite.Database db;
  SqliteConnectionWrapper(this.db);

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? parameters,
  ]) async {
    final stmt = db.prepare(sql);
    final sqlite.ResultSet result =
        parameters == null ? stmt.select() : stmt.select(parameters);
    final rows =
        result.map((row) {
          // row.toTableColumnMap() returns Map<String?, Map<String, dynamic>?>
          final nestedMap = row.toTableColumnMap();
          final flattened = <String, dynamic>{};
          nestedMap?.forEach((table, colMap) {
            flattened.addAll(colMap);
          });
          return flattened;
        }).toList();
    stmt.dispose();
    return rows;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? parameters]) async {
    final stmt = db.prepare(sql);
    if (parameters == null) {
      stmt.execute();
    } else {
      stmt.execute(parameters);
    }
    stmt.dispose();
  }
}

/// MySQL connection wrapper.
class MySQLConnectionWrapper implements DbConnection {
  final mysql.MySqlConnection connection;
  MySQLConnectionWrapper(this.connection);

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? parameters,
  ]) async {
    final result =
        parameters == null
            ? await connection.query(sql)
            : await connection.query(sql, parameters);
    final rows = result.map((row) => row.fields).toList();
    return rows;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? parameters]) async {
    if (parameters == null) {
      await connection.query(sql);
    } else {
      await connection.query(sql, parameters);
    }
  }
}

/// PostgreSQL connection wrapper.
class PostgresConnectionWrapper implements DbConnection {
  final Connection connection;
  PostgresConnectionWrapper(this.connection);

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? parameters,
  ]) async {
    Result result;

    if (parameters == null) {
      result = await connection.execute(sql);
    } else {
      String sqlRaw = sql;

      for (var i = 1; i <= parameters.length; i++) {
        sqlRaw = sqlRaw.replaceFirst('?', '\$$i');
      }

      result = await connection.execute(sqlRaw, parameters: parameters);
    }

    final rows = result.map((row) => row.toColumnMap()).toList();
    return rows;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? parameters]) async {
    if (parameters == null) {
      await connection.execute(sql);
    } else {
      String sqlRaw = sql;

      for (var i = 1; i <= parameters.length; i++) {
        sqlRaw = sqlRaw.replaceFirst('?', '\$$i');
      }

      await connection.execute(sqlRaw, parameters: parameters);
    }
  }
}

/// Handles connecting to the database and storing the global connection instance.
class DpaConnection {
  static DbConnection? _instance;

  /// Returns the global database connection instance.
  static DbConnection get instance => _instance!;

  /// Connects to the database as per the configuration in the application.yaml.
  static Future<DbConnection> connect({String? configPath}) async {
    final config = await ApplicationConfig.load(filePath: configPath);
    final uri = config.databaseUri;

    switch (uri.scheme) {
      case 'sqlite':
        _instance = await _connectSQLite(uri);
        break;
      case 'mysql':
        _instance = await _connectMySQL(
          uri,
          config.username!,
          config.password!,
        );
        break;
      case 'postgresql':
      case 'postgres':
        _instance = await _connectPostgres(
          uri,
          config.username!,
          config.password!,
        );
        break;
      default:
        throw Exception("Unsupported database: ${uri.scheme}");
    }
    return _instance!;
  }

  static Future<DbConnection> _connectSQLite(Uri uri) async {
    if (uri.path == ':memory:') {
      print("Using SQLite in memory.");
      final db = sqlite.sqlite3.openInMemory();
      return SqliteConnectionWrapper(db);
    }
    final dbDirectory = Directory('database');
    final dbPath = 'database/${uri.host}';
    if (!dbDirectory.existsSync()) {
      dbDirectory.createSync(recursive: true);
    }
    final db = sqlite.sqlite3.open(dbPath);
    print("SQLite database created at: $dbPath");
    return SqliteConnectionWrapper(db);
  }

  static Future<DbConnection> _connectMySQL(
    Uri uri,
    String username,
    String password,
  ) async {
    final settings = mysql.ConnectionSettings(
      host: uri.host,
      port: uri.port,
      user: username,
      password: password,
      db: uri.path.substring(1),
    );
    final conn = await mysql.MySqlConnection.connect(settings);

    return MySQLConnectionWrapper(conn);
  }

  static Future<DbConnection> _connectPostgres(
    Uri uri,
    String username,
    String password,
  ) async {
    final endpoint = Endpoint(
      host: uri.host,
      database: uri.path.substring(1),
      username: username,
      password: password,
    );
    final conn = await Connection.open(
      endpoint,
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    return PostgresConnectionWrapper(conn);
  }
}
