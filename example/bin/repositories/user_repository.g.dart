// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_repository.dart';

// **************************************************************************
// DpaRepositoryGenerator
// **************************************************************************

class UserRepositoryImpl implements UserRepository {
  dynamic get _connection => DpaConnection.instance;

  @override
  Future<User?> findById(String id) async {
    final results = await _connection.query(
      "SELECT * FROM users WHERE id = ?",
      [id],
    );
    return results.isNotEmpty ? User().fromMap(results.first) : null;
  }

  @override
  Future<List<User>> findAll() async {
    final results = await _connection.query("SELECT * FROM users") as List;
    return results.isNotEmpty
        ? results.toList().map((row) => User().fromMap(row)).toList()
        : [];
  }

  @override
  Future<void> save(User entity) async {
    // Retrieve generation type from the generated extension
    final generationType = UserGenerated.primaryKeyGenerationType;

    // Check if the primary key is null using the getter
    if (entity.id == null) {
      // Generate primary key based on generation strategy
      if (generationType == GenerationType.UUID) {
        entity = entity.copy(id: Uuid().v4());
      } else if (generationType == GenerationType.CUID) {
        entity = entity.copy(id: cuid());
      } else if (generationType == GenerationType.AUTO) {
        entity = entity.copy(id: null);
      }

      // Insert new entity
      final map = entity.toMap();
      final columns = map.keys.join(', ');
      final placeholders = map.keys.map((_) => '?').join(', ');
      final values = map.values.toList();
      await _connection.execute(
        "INSERT INTO users ($columns) VALUES ($placeholders)",
        values,
      );
    } else {
      // Update existing entity
      final map = entity.toMap();
      final pkName = UserGenerated.primaryKeyName;
      // Remove the primary key from the update set
      final updateMap = Map.of(map)..remove(pkName);
      final setClause = updateMap.keys.map((col) => "$col = ?").join(', ');
      final values = updateMap.values.toList();
      values.add(entity.id);
      await _connection.execute(
        "UPDATE users SET $setClause WHERE $pkName = ?",
        values,
      );
    }
  }

  @override
  Future<void> saveAll(List<User> entities) async {
    for (final entity in entities) {
      await save(entity);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    await _connection.execute("DELETE FROM users WHERE id = ?", [id]);
  }

  @override
  Future<void> deleteAll() async {
    await _connection.execute("DELETE FROM users");
  }

  @override
  Future<int> count() async {
    final result = await _connection.query(
      "SELECT COUNT(*) as count FROM users",
    );
    return result.isNotEmpty ? result.first["count"] as int : 0;
  }
}
