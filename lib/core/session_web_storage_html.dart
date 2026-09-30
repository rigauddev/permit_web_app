import 'package:web/web.dart' as web;

const _backupKey = 'permit_web_session_backup_v1';

String? readWebSessionBackup() =>
    web.window.localStorage.getItem(_backupKey) ??
    web.window.sessionStorage.getItem(_backupKey);

Future<void> writeWebSessionBackup(String value) async {
  web.window.localStorage.setItem(_backupKey, value);
  web.window.sessionStorage.setItem(_backupKey, value);
}

Future<void> clearWebSessionBackup() async {
  web.window.localStorage.removeItem(_backupKey);
  web.window.sessionStorage.removeItem(_backupKey);
}
