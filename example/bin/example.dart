import 'package:boing_data_dpa/boing_data_dpa.dart';
import 'package:darto/darto.dart';
import 'package:example/routes/users_routes.dart';

Future<void> main() async {
  await DpaConnection.connect();

  final initializer = DpaInitializer(DpaConnection.instance);
  await initializer.initialize();

  final app = Darto();

  app.use(usersRoutes);

  app.listen(8080, () {
    print('Server listening on port 8080');
  });
}
