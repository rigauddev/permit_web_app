import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSession {
  const SavedSession({
    required this.accessToken,
    required this.userJson,
    required this.expiresAt,
  });

  final String accessToken;
  final String userJson;
  final DateTime expiresAt;
}

class SessionStore {
  const SessionStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const accessTokenKey = 'access_token';
  static const userKey = 'user';
  static const sessionExpiresAtKey = 'session_expires_at';
  static const _secureStorageTimeout = Duration(milliseconds: 800);

  final FlutterSecureStorage _secureStorage;

  Future<void> save({
    required String accessToken,
    required String userJson,
    required String expiresAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(accessTokenKey, accessToken);
    await preferences.setString(userKey, userJson);
    await preferences.setString(sessionExpiresAtKey, expiresAt);
    try {
      await _secureStorage
          .write(key: accessTokenKey, value: accessToken)
          .timeout(_secureStorageTimeout);
      await _secureStorage
          .write(key: userKey, value: userJson)
          .timeout(_secureStorageTimeout);
      await _secureStorage
          .write(key: sessionExpiresAtKey, value: expiresAt)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // SharedPreferences mantém a sessão como fallback quando o storage seguro falha.
    }
  }

  Future<SavedSession?> read() async {
    final accessToken = await _readValue(accessTokenKey);
    final userJson = await _readValue(userKey);
    final expiresAtText = await _readValue(sessionExpiresAtKey);
    final expiresAt =
        expiresAtText == null ? null : DateTime.tryParse(expiresAtText);
    if (accessToken == null || userJson == null) {
      return null;
    }
    final effectiveExpiresAt =
        expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 5));
    final effectiveExpiresAtText = effectiveExpiresAt.toUtc().toIso8601String();
    if (expiresAt == null) {
      await save(
        accessToken: accessToken,
        userJson: userJson,
        expiresAt: effectiveExpiresAtText,
      );
    }
    await _syncSecureStorage(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: effectiveExpiresAtText,
    );
    return SavedSession(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: effectiveExpiresAt,
    );
  }

  Future<void> clear() async {
    try {
      await _secureStorage
          .delete(key: accessTokenKey)
          .timeout(_secureStorageTimeout);
      await _secureStorage.delete(key: userKey).timeout(_secureStorageTimeout);
      await _secureStorage
          .delete(key: sessionExpiresAtKey)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // O fallback abaixo também precisa ser limpo.
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accessTokenKey);
    await preferences.remove(userKey);
    await preferences.remove(sessionExpiresAtKey);
  }

  Future<String?> readUserJson() async {
    return _readValue(userKey);
  }

  Future<void> updateUserJson(String userJson) async {
    final session = await read();
    if (session == null) return;
    await save(
      accessToken: session.accessToken,
      userJson: userJson,
      expiresAt: session.expiresAt.toUtc().toIso8601String(),
    );
  }

  Future<String?> _readValue(String key) async {
    String? secureValue;
    try {
      secureValue = await _secureStorage
          .read(key: key)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      secureValue = null;
    }
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }
    final preferences = await SharedPreferences.getInstance();
    final webValue = preferences.getString(key);
    return webValue == null || webValue.isEmpty ? null : webValue;
  }

  Future<void> _syncSecureStorage({
    required String accessToken,
    required String userJson,
    required String expiresAt,
  }) async {
    try {
      await _secureStorage
          .write(key: accessTokenKey, value: accessToken)
          .timeout(_secureStorageTimeout);
      await _secureStorage
          .write(key: userKey, value: userJson)
          .timeout(_secureStorageTimeout);
      await _secureStorage
          .write(key: sessionExpiresAtKey, value: expiresAt)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // SharedPreferences already preserved the web session.
    }
  }
}
