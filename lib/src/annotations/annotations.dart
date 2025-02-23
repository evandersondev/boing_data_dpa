/// Define a entity in DPA
class Entity {
  const Entity();
}

/// Define a table in DPA
class Table {
  final String name;
  const Table({required this.name});
}

/// Define a getter and setter for a field in DPA
class Data {
  const Data();
}

/// Define a primary key in DPA
class Id {
  const Id();
}

/// Defines the generation strategy for primary keys
enum GenerationType { AUTO, UUID, CUID }

class GeneratedValue {
  final GenerationType strategy;
  const GeneratedValue({this.strategy = GenerationType.AUTO});
}

/// Defines a column in a table in DPA
class Column {
  final String? name;
  final bool unique;
  final String? columnDefinition;
  const Column({this.name, this.unique = false, this.columnDefinition});
}

/// Defines the temporal type for DateTime fields
/// DATE: yyyy-MM-dd
/// TIME: HH:mm:ss
/// TIMESTAMP: yyyy-MM-ddTHH:mm:ss
enum TemporalType { DATE, TIME, TIMESTAMP }

class Temporal {
  final TemporalType type;
  const Temporal(this.type);
}

/// Defines an enumeration mapping strategy
enum EnumType { ORDINAL, STRING }

class Enumerated {
  final EnumType type;
  const Enumerated(this.type);
}

/// Defines a transient field (not persisted in the database)
class Transient {
  const Transient();
}

/// Defines an ElementCollection for storing lists or maps
class ElementCollection {
  const ElementCollection();
}

/// Defines the JoinColumn annotation for relationships
class JoinColumn {
  final String name;
  const JoinColumn({required this.name});
}

/// Defines a Many-to-One relationship
class ManyToOne {
  const ManyToOne();
}

/// Defines a One-to-Many relationship
class OneToMany {
  final String mappedBy;
  final bool orphanRemoval;
  const OneToMany({required this.mappedBy, this.orphanRemoval = false});
}
