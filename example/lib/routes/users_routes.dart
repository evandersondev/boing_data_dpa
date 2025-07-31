import 'package:darto/darto.dart';
import 'package:example/controllers/user_controller.dart';
import 'package:example/repositories/user_repository.dart';

void usersRoutes(Router router) {
  final repository = UserRepositoryImpl();
  final controller = UserController(repository);

  router.get('/users', controller.getAll);
  router.get('/users/:id', controller.getById);
  router.post('/users', controller.create);
  router.put('/users/:id', controller.update);
  router.put('/users/:id', controller.delete);
}
