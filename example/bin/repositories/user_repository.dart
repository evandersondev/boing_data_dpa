import 'package:boing_data_dpa/boing_data_dpa.dart';

import '../models/user.dart';

part 'user_repository.g.dart';

abstract class UserRepository extends DpaRepository<User, String> {}
