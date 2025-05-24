import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../data/models/user_model.dart';

class AuthService {
  final Map<String, Map<String, String>> _testUsers = {
    'admin@admin.com': {
      'name': 'Administrador',
      'password': hashPassword('123456'),
      'role': 'admin',
      'perfil': 'administrador',
    },
    'user@teste.com': {
      'name': 'Usuário Comum',
      'password': hashPassword('123456'),
      'role': 'user',
      'perfil': 'usuario',
    },
    'gestor@empresa.com': {
      'name': 'Gestor Empresa',
      'password': hashPassword('123456'),
      'role': 'gestor',
      'perfil': 'gestor da empresa',
    },
    'operador@empresa.com': {
      'name': 'Operador Empresa',
      'password': hashPassword('123456'),
      'role': 'operador',
      'perfil': 'operador de sistema',
    }
  };

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<bool> validateLogin(String email, String password) async {
    await Future.delayed(Duration(milliseconds: 300)); // simula delay
    final user = _testUsers[email];
    if (user == null) return false;
    return user['password'] == hashPassword(password);
  }
  Future<bool> validateMfaWithCredentials(String email, String password, String mfaCode) async {
    await Future.delayed(Duration(milliseconds: 300)); // simula delay
    final user = _testUsers[email];
    if (user == null) return false;
    return user['password'] == hashPassword(password) && mfaCode == '123456';
  }

  bool validateMfa(String email, String mfaCode) {
    return mfaCode == '123456' && _testUsers.containsKey(email);
  }

  UserModel? getUser(String email) {
    final user = _testUsers[email];
    if (user == null) return null;

    return UserModel(
      name: user['name']!,
      email: email,
      userType: user['role']!,
      profile: user['perfil']!,
    );
  }

  /// Método auxiliar útil para testes e exibição de todos os usuários mockados
  List<UserModel> getAllMockUsers() {
    return _testUsers.entries.map((entry) {
      final user = entry.value;
      return UserModel(
        name: user['name']!,
        email: entry.key,
        userType: user['role']!,
        profile: user['perfil']!,
      );
    }).toList();
  }
}
