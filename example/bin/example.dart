import 'dart:convert';

import 'package:boing_data_dpa/boing_data_dpa.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import './models/user.dart';
import './repositories/user_repository.dart';
import './utils/hash_password.dart';

Future<void> main() async {
  await DpaConnection.connect();

  final initializer = DpaInitializer(DpaConnection.instance);
  await initializer.initialize();

  final repository = UserRepositoryImpl();

  final router =
      Router()
        ..get('/ping', (Request request) => Response.ok('pong'))
        ..get('/users', (Request request) async {
          final users = await repository.findAll();
          final usersMap = users.map((user) => user.toMap()).toList();
          return Response.ok(
            json.encode(usersMap),
            headers: {'Content-Type': 'application/json'},
          );
        })
        ..post('/users', (Request request) async {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final user = User().fromMap(data);
          await repository.save(
            user.copy(password: hashPassword(user.password)),
          );
          return Response(201);
        })
        ..get('/users/<id>', (Request request, String id) async {
          final user = await repository.findById(id);
          if (user == null) {
            return Response.notFound('Usuário não encontrado');
          }
          return Response.ok(
            json.encode(user.toMap()),
            headers: {'Content-Type': 'application/json'},
          );
        })
        ..put('/users/<id>', (Request request, String id) async {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final user = User().fromMap(data);
          await repository.save(user);
          return Response(204);
        })
        ..delete('/users/<id>', (Request request, String id) async {
          await repository.deleteById(id);
          return Response(204);
        })
        ..get(
          '/db',
          (Request request) =>
              Response.ok('Conectado ao BD: ${DpaConnection.instance}'),
        );

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await io.serve(handler, 'localhost', 8080);
  print('Servidor rodando em http://${server.address.host}:${server.port}');
}
