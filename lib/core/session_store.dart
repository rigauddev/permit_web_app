import 'dart:async';
import 'dart:convert';

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
  // No navegador a sessão é guardada como um único valor no localStorage.
  // Isso impede que uma atualização encontre apenas parte dos três campos
  // antigos durante a inicialização do Flutter.
  static const _webSessionKey = 'permit_web_session_v1';
  static const _secureStorageTimeout = Duration(milliseconds: 800);

  final FlutterSecureStorage _secureStorage;

  Future<void> save({
    required String accessToken,
    required String userJson,
    required String expiresAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await preferences.setString(
        _webSessionKey,
        jsonEncode({
          'accessToken': accessToken,
          'userJson': userJson,
          'expiresAt': expiresAt,
        }),
      );
      return;
    }
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
    if (kIsWeb) return _readWebSession();

    final accessToken = await _readValue(accessTokenKey);
    final userJson = await _readValue(userKey);
    final expiresAtText = await _readValue(sessionExpiresAtKey);
    final expiresAt =
        expiresAtText == null ? null : DateTime.tryParse(expiresAtText);
    if (accessToken == null || userJson == null) {
      return null;
    }
    if (expiresAt == null) {
      await clear();
      return null;
    }
    final effectiveExpiresAt = expiresAt;
    final effectiveExpiresAtText = effectiveExpiresAt.toUtc().toIso8601String();
    if (effectiveExpiresAt.toUtc().isBefore(DateTime.now().toUtc())) {
      await clear();
      return null;
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
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_webSessionKey);
      // Limpa também o formato usado pelas versões anteriores.
      await preferences.remove(accessTokenKey);
      await preferences.remove(userKey);
      await preferences.remove(sessionExpiresAtKey);
      return;
    }
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
    if (kIsWeb) return (await read())?.userJson;
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
    final preferences = await SharedPreferences.getInstance();
    final preferencesValue = preferences.getString(key);
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
    return preferencesValue == null || preferencesValue.isEmpty
        ? null
        : preferencesValue;
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

  Future<SavedSession?> _readWebSession() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_webSessionKey);
    if (saved == null || saved.isEmpty) {
      return _migrateLegacyWebSession(preferences);
    }

    try {
      final data = jsonDecode(saved);
      if (data is! Map) throw const FormatException('Sessão inválida');
      final accessToken = data['accessToken']?.toString();
      final userJson = data['userJson']?.toString();
      final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      if (accessToken == null ||
          accessToken.isEmpty ||
          userJson == null ||
          userJson.isEmpty ||
          expiresAt == null) {
        throw const FormatException('Sessão incompleta');
      }
      if (!expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        await clear();
        return null;
      }
      return SavedSession(
        accessToken: accessToken,
        userJson: userJson,
        expiresAt: expiresAt,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<SavedSession?> _migrateLegacyWebSession(
    SharedPreferences preferences,
  ) async {
    final accessToken = preferences.getString(accessTokenKey);
    final userJson = preferences.getString(userKey);
    final expiresAt = DateTime.tryParse(
      preferences.getString(sessionExpiresAtKey) ?? '',
    );
    if (accessToken == null ||
        accessToken.isEmpty ||
        userJson == null ||
        userJson.isEmpty ||
        expiresAt == null ||
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      await clear();
      return null;
    }
    await save(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: expiresAt.toUtc().toIso8601String(),
    );
    return SavedSession(
      accessToken: accessToken,
      userJson: userJson,
      expiresAt: expiresAt,
    );
  }
}
