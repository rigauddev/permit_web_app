import 'package:flutter/material.dart';

import 'session_store.dart';

class SessionExpiration {
  static const _sessionStore = SessionStore();

  static Future<String?> readAccessToken() async {
    final session = await _sessionStore.read();
    return session?.accessToken;
  }

  static Future<void> logout(BuildContext context) async {
    await _sessionStore.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }
}
