import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

/// Sesión en el almacenamiento seguro del dispositivo.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_session';
  final FlutterSecureStorage _storage;

  @override
  Future<PersistedSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    final session = PersistedSession.tryDecode(raw);
    if (session == null) {
      await _storage.delete(key: _key);
      return null;
    }
    return session;
  }

  @override
  Future<void> save(PersistedSession session) {
    return _storage.write(key: _key, value: session.encode());
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _key);
  }
}
