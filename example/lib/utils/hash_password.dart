import 'package:bcrypt/bcrypt.dart';

String hashPassword(String plainPassword) {
  return BCrypt.hashpw(plainPassword, BCrypt.gensalt());
}

bool verifyPassword(String plainPassword, String hashedPassword) {
  return BCrypt.checkpw(plainPassword, hashedPassword);
}

void main() {
  final plainPassword = 'minha_senha_super_secreta';
  final hashed = hashPassword(plainPassword);

  print('Senha criptografada: $hashed');

  final isValid = verifyPassword(plainPassword, hashed);
  print('Senha válida: $isValid');
}
