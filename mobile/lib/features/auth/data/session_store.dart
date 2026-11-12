import 'dart:convert';

import '../domain/auth_model.dart';

/// Sesión que sobrevive al cierre del proceso.
class PersistedSession {
  final User user;
  final bool mustChangePassword;
  final Merchant? merchant;

  const PersistedSession({
    required this.user,
    required this.mustChangePassword,
    required this.merchant,
  });

  PersistedSession copyWith({
    User? user,
    bool? mustChangePassword,
    Merchant? merchant,
  }) {
    return PersistedSession(
      user: user ?? this.user,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      merchant: merchant ?? this.merchant,
    );
  }

  String encode() {
    return jsonEncode({
      'name': user.name,
      'email': user.email,
      'token': user.token,
      'must_change_password': mustChangePassword,
      'merchant': merchant?.toJson(),
    });
  }

  static PersistedSession? tryDecode(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      final name = data['name'];
      final email = data['email'];
      final token = data['token'];
      if (name is! String ||
          email is! String ||
          token is! String ||
          token.isEmpty) {
        return null;
      }

      Merchant? merchant;
      final rawMerchant = data['merchant'];
      if (rawMerchant != null) {
        merchant = Merchant.tryParse(rawMerchant);
        if (merchant == null) return null;
      }

      return PersistedSession(
        user: User(name: name, email: email, token: token),
        mustChangePassword: data['must_change_password'] == true,
        merchant: merchant,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lectura y borrado de la sesión guardada.
abstract class SessionStore {
  Future<PersistedSession?> read();

  Future<void> save(PersistedSession session);

  Future<void> clear();
}

/// Store de pruebas y valor por defecto del cubit fuera de la app.
class MemorySessionStore implements SessionStore {
  PersistedSession? _session;

  @override
  Future<PersistedSession?> read() async => _session;

  @override
  Future<void> save(PersistedSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
