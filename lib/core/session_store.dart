import 'package:flutter/foundation.dart';
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

  final FlutterSecureStorage _secureStorage;

  Future<void> save({
    required String accessToken,
    required String userJson,
    required String expiresAt,
  }) async {
    try {
      await _secureStorage.write(key: accessTokenKey, value: accessToken);
      await _secureStorage.write(key: userKey, value: userJson);
      await _secureStorage.write(key: sessionExpiresAtKey, value: expiresAt);
    } catch (_) {
      // No web, persistimos abaixo em SharedPreferences como fallback.
    }
    if (!kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(accessTokenKey, accessToken);
    await preferences.setString(userKey, userJson);
    await preferences.setString(sessionExpiresAtKey, expiresAt);
  }

  Future<SavedSession?> read() async {
    final accessToken = await _readValue(accessTokenKey);
    final userJson = await _readValue(userKey);
    final expiresAtText = await _readValue(sessionExpiresAtKey);
    final expiresAt =
        expiresAtText == null ? null : DateTime.tryParse(expiresAtText);
    if (accessToken == null || userJson == null || expiresAt == null) {
      return null;
    }
    await _syncSecureStorage(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: expiresAtText!,
    );
    return SavedSession(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: expiresAt,
    );
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: accessTokenKey);
      await _secureStorage.delete(key: userKey);
      await _secureStorage.delete(key: sessionExpiresAtKey);
    } catch (_) {
      // No web, fallback storage below is the source of truth when secure storage fails.
    }
    if (!kIsWeb) return;
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
      secureValue = await _secureStorage.read(key: key);
    } catch (_) {
      secureValue = null;
    }
    if (!kIsWeb || (secureValue != null && secureValue.isNotEmpty)) {
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
    if (!kIsWeb) return;
    try {
      await _secureStorage.write(key: accessTokenKey, value: accessToken);
      await _secureStorage.write(key: userKey, value: userJson);
      await _secureStorage.write(key: sessionExpiresAtKey, value: expiresAt);
    } catch (_) {
      // SharedPreferences already preserved the web session.
    }
  }
}
