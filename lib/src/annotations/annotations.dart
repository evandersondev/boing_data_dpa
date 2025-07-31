/// Define uma entidade no DPA
class Entity {
  const Entity();
}

/// Define uma tabela no DPA
class Table {
  final String name;
  final List<String> indexes;
  const Table({required this.name, this.indexes = const []});
}

/// Define um getter e setter para um campo no DPA
class Data {
  const Data();
}

/// Define uma chave primária no DPA
class Id {
  const Id();
}

/// Define a estratégia de geração para chaves primárias
enum GenerationType { AUTO, UUID, CUID }

class GeneratedValue {
  final GenerationType strategy;
  const GeneratedValue({this.strategy = GenerationType.AUTO});
}

/// Define uma coluna em uma tabela no DPA
class Column {
  final String? name;
  final bool unique;
  final bool nullable;
  final String? columnDefinition;
  const Column({
    this.name,
    this.unique = false,
    this.nullable = true,
    this.columnDefinition,
  });
}

/// Define o tipo temporal para campos DateTime
enum TemporalType { DATE, TIME, TIMESTAMP }

class Temporal {
  final TemporalType type;
  const Temporal(this.type);
}

/// Define a estratégia de mapeamento para enums
enum EnumType { ORDINAL, STRING }

class Enumerated {
  final EnumType type;
  const Enumerated(this.type);
}

/// Define um campo transitório (não persistido no banco)
class Transient {
  const Transient();
}

/// Define uma coleção de elementos para listas ou mapas
class ElementCollection {
  final String? collectionTable;
  const ElementCollection({this.collectionTable});
}

/// Define uma coluna de junção para relacionamentos
class JoinColumn {
  final String name;
  final bool nullable;
  const JoinColumn({required this.name, this.nullable = true});
}

/// Define um relacionamento Many-to-One
class ManyToOne {
  final String? fetch;
  const ManyToOne({this.fetch = 'LAZY'});
}

/// Define um relacionamento One-to-Many
class OneToMany {
  final String mappedBy;
  final bool orphanRemoval;
  final String? fetch;
  const OneToMany({
    required this.mappedBy,
    this.orphanRemoval = false,
    this.fetch = 'LAZY',
  });
}

/// Define um campo de versionamento para controle otimista
class Version {
  const Version();
}
