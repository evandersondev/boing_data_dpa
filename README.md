# Boing Data - Dart Persistent API (DPA) 🚀

Boing Data DPA is a Dart/Flutter package inspired by Spring Data JPA, offering simplified data persistence using annotations. It supports SQLite, PostgreSQL, and MySQL databases.

## Installation 🔧

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  boing_data_dpa: ^0.0.1
  build_runner: any
```

## Configuration ⚙️

### Defining the Connection

The package allows defining connections with different databases. Configure it in `application.yaml`:

```yaml
# SQLITE
dpa:
  datasource:
    url: "sqlite:///database.db"

# POSTGRES
dpa:
  datasource:
    url: "postgres://localhost:5432/mydatabase"
    username: "username"
    password: "password"

# MYSQL
dpa:
  datasource:
    url: "mysql://localhost:3306/mydatabase"
    username: "username"
    password: "password"
```

Or define it directly in the code:

```dart
final uri = Uri.parse("sqlite:///database.db");
DpaConnection.connect(uri);
```

## Defining Migrations 📜

Create the `database/migrations.sql` file and define your database schema according to the database type:

```sql
--- SQLITE
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, -- UUID
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT
);

--- MYSQL
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY, -- UUID
  name VARCHAR(200) NOT NULL,
  surname VARCHAR(200) NOT NULL,
  email VARCHAR(200) UNIQUE NOT NULL,
  password VARCHAR(200) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--- POSTGRES
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY, --UUID
    name VARCHAR(255) NOT NULL,
    surname VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Creating an Entity 🏗️

Use annotations to define an entity:

```dart
import 'package:boing_data_dpa/boing_data_dpa.dart';

part 'user.g.dart';

@Entity()
@Table(name: "users")
@Data()
class User {
  @Id()
  @GeneratedValue(strategy: GenerationType.UUID)
  late String? id;

  late String name;
  late String surname;
  @Column(unique: true)
  late String email;
  late String password;

  @Column()
  @Temporal(TemporalType.DATE)
  late DateTime createdAt;

  @Column()
  @Temporal(TemporalType.DATE)
  late DateTime updatedAt;
}
```

## Creating a Repository 📦

Define a repository to handle entity data:

```dart
import 'package:boing_data_dpa/boing_data_dpa.dart';
import '../models/user.dart';

part 'user_repository.g.dart';

abstract class UserRepository extends DpaRepository<User, String> {}
```

The generated code will automatically implement CRUD methods.

```shell
  dart run build_runner build
```

## CRUD Operations 🔄

```dart
final repository = UserRepositoryImpl();

// Creating a user
final user = User()
  ..name = "John"
  ..surname = "Doe"
  ..email = "john.doe@example.com"
  ..password = "123456"
  ..createdAt = DateTime.now()
  ..updatedAt = DateTime.now();
await repository.save(user);

// Fetching all users
List<User> users = await repository.findAll();

// Fetching a user by ID
User? user = await repository.findById("some-id");

// Updating a user
user?.name = "Jane";
await repository.save(user!);

// Deleting a user
await repository.deleteById("some-id");
```

## REST API Example 🌍

Use `shelf` to expose a CRUD API:

```dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:boing_data_dpa/boing_data_dpa.dart';
import '../repositories/user_repository.dart';

Future<void> main() async {
  await DpaConnection.connect();
  final repository = UserRepositoryImpl();

  final router = Router()
    ..get('/users', (Request request) async {
      final users = await repository.findAll();
      return Response.ok(json.encode(users.map((u) => u.toMap()).toList()),
          headers: {'Content-Type': 'application/json'});
    })
    ..post('/users', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final user = User().fromMap(data);
      await repository.save(user);
      return Response(201);
    });

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running at http://${server.address.host}:${server.port}');
}
```

## Conclusion 🎯

Boing Data DPA simplifies data persistence in Dart using an annotation-based model and repositories.
Feel free to contribute and improve the package! 🚀
