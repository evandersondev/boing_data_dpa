import 'dart:convert';

class Test {
  final String name;

  Test({required this.name});

  Test copyWith({String? name}) {
    return Test(name: name ?? this.name);
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'name': name});

    return result;
  }

  factory Test.fromMap(Map<String, dynamic> map) {
    return Test(name: map['name'] ?? '');
  }

  String toJson() => json.encode(toMap());

  factory Test.fromJson(String source) => Test.fromMap(json.decode(source));

  @override
  String toString() => 'Test(name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Test && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
