import 'package:boing_data_dpa/boing_data_dpa.dart';

part 'user.g.dart';

@Entity()
@Table(name: "users")
@Data()
class User {
  @Id()
  @GeneratedValue(strategy: GenerationType.UUID)
  late String? _id;

  late String _name;
  late String _surname;
  @Column(unique: true)
  late String _email;
  late String _password;

  @Column()
  @Temporal(TemporalType.DATE)
  late DateTime _createdAt;

  @Column()
  @Temporal(TemporalType.DATE)
  late DateTime _updatedAt;
}
