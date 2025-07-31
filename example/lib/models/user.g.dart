// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// DpaEntityGenerator
// **************************************************************************

extension UserGenerated on User {
  static String primaryKeyName = 'id';
  static GenerationType primaryKeyGenerationType = GenerationType.UUID;

  String? get id => _id;
  set id(String? id) => _id = id;
  String get name => _name;
  set name(String name) => _name = name;
  String get surname => _surname;
  set surname(String surname) => _surname = surname;
  String get email => _email;
  set email(String email) => _email = email;
  String get password => _password;
  set password(String password) => _password = password;
  DateTime get createdAt => _createdAt;
  set createdAt(DateTime createdAt) => _createdAt = createdAt;
  DateTime get updatedAt => _updatedAt;
  set updatedAt(DateTime updatedAt) => _updatedAt = updatedAt;

  User copy({
    String? id,
    String? name,
    String? surname,
    String? email,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User()
      ..id = id ?? _id
      ..name = name ?? _name
      ..surname = surname ?? _surname
      ..email = email ?? _email
      ..password = password ?? _password
      ..createdAt = createdAt ?? _createdAt
      ..updatedAt = updatedAt ?? _updatedAt;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map.addAll({'id': id});
    map.addAll({'name': name});
    map.addAll({'surname': surname});
    map.addAll({'email': email});
    map.addAll({'password': password});
    map.addAll({'created_at': createdAt.toIso8601String()});
    map.addAll({'updated_at': updatedAt.toIso8601String()});

    return map;
  }

  User fromMap(Map<String, dynamic> map) {
    return User()
      ..id = map["id"]
      ..name = map["name"]
      ..surname = map["surname"]
      ..email = map["email"]
      ..password = map["password"]
      ..createdAt = DateTime.parse("${map["created_at"]}")
      ..updatedAt = DateTime.parse("${map["updated_at"]}");
  }
}
