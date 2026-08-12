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
    await _secureStorage.write(key: accessTokenKey, value: accessToken);
    await _secureStorage.write(key: userKey, value: userJson);
    await _secureStorage.write(key: sessionExpiresAtKey, value: expiresAt);
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
    await _secureStorage.delete(key: accessTokenKey);
    await _secureStorage.delete(key: userKey);
    await _secureStorage.delete(key: sessionExpiresAtKey);
    if (!kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accessTokenKey);
    await preferences.remove(userKey);
    await preferences.remove(sessionExpiresAtKey);
  }

  Future<String?> _readValue(String key) async {
    final secureValue = await _secureStorage.read(key: key);
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
    await _secureStorage.write(key: accessTokenKey, value: accessToken);
    await _secureStorage.write(key: userKey, value: userJson);
    await _secureStorage.write(key: sessionExpiresAtKey, value: expiresAt);
  }
}
