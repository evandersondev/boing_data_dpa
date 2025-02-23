import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Reads the application's configuration from application.yaml using the "boing" section.
class ApplicationConfig {
  final String databaseUrl;
  final String? username;
  final String? password;

  ApplicationConfig._({
    required this.databaseUrl,
    this.username,
    this.password,
  });

  static ApplicationConfig? _instance;

  /// Loads the configuration from application.yaml located at the project root.
  /// The expected YAML structure is:
  ///
  /// boing:
  ///   datasource:
  ///     url: "sqlite://database.db"
  ///     // For MySQL or Postgres:
  ///     username: "user"
  ///     password: "userpassword"
  ///
  /// If [filePath] is not provided, it defaults to "application.yaml" in the current directory.
  static Future<ApplicationConfig> load({String? filePath}) async {
    if (_instance != null) return _instance!;
    final defaultPath = p.join(Directory.current.path, 'application.yaml');
    final configPath = filePath ?? defaultPath;
    final file = File(configPath);

    if (!await file.exists()) {
      throw Exception(
        "Arquivo application.yaml não encontrado em: $configPath",
      );
    }

    final yamlStr = await file.readAsString();
    final yamlMap = loadYaml(yamlStr);

    if (yamlMap == null || yamlMap['boing'] == null) {
      throw Exception("A seção 'boing' não foi encontrada em application.yaml");
    }

    final boingConfig = yamlMap['boing'];
    if (boingConfig == null) {
      throw Exception("A seção 'boing' não foi encontrada em application.yaml");
    }

    final datasourceConfig = boingConfig['datasource'];
    if (datasourceConfig == null) {
      throw Exception(
        "Chave 'datasource' não encontrada em application.yaml dentro de 'boing'",
      );
    }

    final dbUrl = datasourceConfig['url'];
    if (dbUrl == null) {
      throw Exception(
        "Chave 'url' não encontrada em application.yaml dentro de 'boing'",
      );
    }

    // Parse the database URL to check the scheme
    final dbUri = Uri.parse(dbUrl.toString());
    String? username;
    String? password;
    if (dbUri.scheme == 'mysql' || dbUri.scheme == 'postgres') {
      username = datasourceConfig['username'];
      password = datasourceConfig['password'];
      if (username == null) {
        throw Exception(
          "Chave 'username' é obrigatória para MySQL ou Postgres em application.yaml",
        );
      }
      if (password == null) {
        throw Exception(
          "Chave 'password' é obrigatória para MySQL ou Postgres em application.yaml",
        );
      }
    }

    _instance = ApplicationConfig._(
      databaseUrl: dbUrl.toString(),
      username: username?.toString(),
      password: password?.toString(),
    );
    return _instance!;
  }

  /// Returns the parsed database Uri.
  Uri get databaseUri => Uri.parse(databaseUrl);
}
