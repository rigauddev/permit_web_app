
import '../data/models/user_model.dart';

class AuthService {

  final Map<String, Map<String, String>> _testUsers = {
    'admin@admin.com': {
      'name': 'Test User',
      'password': '123456',
      'role': 'admin',
      'perfil': 'administrador',
    },
    'test2@test.com': {
      'name': 'Usuario',
      'password': '123456',
      'role': 'user',
      'perfil': 'usuario',
    },
    'test3@test.com': {
      'name': 'Test User 3',
      'password': '123456',
      'role': 'gestor',
      'perfil': 'gestor',
    },
    'test4@test.com': {
      'name': 'Test User 4',
      'password': '123456',
      'role': 'operador',
      'perfil': 'operador de sistema',
    }
  };
  bool validateLogin(String email, String password) {
    return _testUsers.containsKey(email) &&
           _testUsers[email]!['password'] == password;
  }

  bool validateMfa(String email, String mfaCode) {
    return mfaCode == '123456' && _testUsers.containsKey(email);
  }

  UserModel getUser(String email) {
    final user = _testUsers[email]!;
    return UserModel(
      name: user['name']!,
      email: email,
      password: user['password']!,
      tipoUsuario: user['role']!,
    );
  }
}
