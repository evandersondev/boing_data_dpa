import 'package:darto/darto.dart';
import 'package:example/models/user.dart';

import '../repositories/user_repository.dart';
import '../utils/hash_password.dart';

class UserController {
  final UserRepository _repository;

  UserController(this._repository);

  Handler getAll(Request req, Response res) async {
    final users = await _repository.findAll();

    return res.json({'data': users.map((user) => user.toMap()).toList()});
  }

  Handler getById(Request req, Response res) async {
    final id = req.param['id'] ?? '';
    final user = await _repository.findById(id);

    if (user == null) {
      return res.status(404).json('Usuário não encontrado');
    }

    return res.json({'data': user.toMap()});
  }

  Handler create(Request req, Response res) async {
    final body = await req.body;

    final user = User().fromMap(body);
    await _repository.save(user.copy(password: hashPassword(user.password)));

    return res.status(201).end();
  }

  Handler update(Request req, Response res) async {
    final id = req.param['id'] ?? '';
    final body = await req.body;

    final user = User().fromMap(body).copy(id: id);
    await _repository.save(user);

    return res.json({'data': user.toMap()});
  }

  Handler delete(Request req, Response res) async {
    final id = req.param['id'] ?? '';

    await _repository.deleteById(id);

    return res.status(200).end();
  }
}
