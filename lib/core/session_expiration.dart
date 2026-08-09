import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionExpiration {
  static const _storage = FlutterSecureStorage();

  static Future<void> logout(BuildContext context) async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user');
    await _storage.delete(key: 'session_expires_at');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }
}
