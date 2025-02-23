import './models/user.dart';
import './repositories/user_repository.dart';

class UserController {
  final UserRepository _repository;

  UserController(this._repository);

  Future<List<User>> getAll() async {
    return [];
  }
}
