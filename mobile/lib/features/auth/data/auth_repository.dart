import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../domain/auth_model.dart';

/// Simple in-memory installation ID generator.
///
/// In a production app this would be persisted (e.g. SharedPreferences).
String _resolveInstallationId() {
  // Use a compile-time constant or fall back to the default terminal id.
  // NOTE: 05000001 is a real terminal (GOBIERNO) used for the local demo,
  // not a throwaway dev-only value.
  const fromDefine = String.fromEnvironment(
    'INSTALLATION_ID',
    defaultValue: '05000001',
  );
  return fromDefine;
}

class AuthRepository {
  final http.Client _httpClient;
  final String _baseUrl;

  AuthRepository({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'username': usernameOrEmail,
              'password': password,
              'installation_id': _resolveInstallationId(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final bool mustChange = data['must_change_password'] == true;

        return AuthResponse(
          isSuccess: true,
          user: User(
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            token: data['token'] ?? '',
          ),
          merchant: Merchant.tryParse(data['merchant']),
          message: 'Inicio de sesión exitoso',
          mustChangePassword: mustChange,
        );
      } else {
        return AuthResponse(
          isSuccess: false,
          message: data['message'] ?? 'Credenciales inválidas',
        );
      }
    } on TimeoutException {
      return const AuthResponse(
        isSuccess: false,
        message: 'Tiempo de espera agotado. Verifique su conexión.',
      );
    } on SocketException {
      return const AuthResponse(
        isSuccess: false,
        message: 'No se pudo conectar con el servidor.',
      );
    } catch (e) {
      return const AuthResponse(
        isSuccess: false,
        message: 'Ocurrió un error inesperado. Reintente.',
      );
    }
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'installation_id': _resolveInstallationId(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse(
          isSuccess: true,
          user: User(
            name: data['name'] ?? name,
            email: data['email'] ?? email,
            token: data['token'] ?? '',
          ),
          message: 'Registro exitoso',
        );
      } else {
        return AuthResponse(
          isSuccess: false,
          message: data['message'] ?? 'Error al registrar usuario',
        );
      }
    } on TimeoutException {
      return const AuthResponse(
        isSuccess: false,
        message: 'Tiempo de espera agotado. Verifique su conexión.',
      );
    } on SocketException {
      return const AuthResponse(
        isSuccess: false,
        message: 'No se pudo conectar con el servidor.',
      );
    } catch (e) {
      return const AuthResponse(
        isSuccess: false,
        message: 'Ocurrió un error inesperado. Reintente.',
      );
    }
  }

  /// Comercio vigente de la cuenta. Un fallo de red no borra el del login.
  Future<MerchantLookup> fetchCurrentMerchant({required String token}) async {
    final url = Uri.parse('$_baseUrl/me/merchant');

    try {
      final response = await _httpClient
          .get(url, headers: {HttpHeaders.authorizationHeader: 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const MerchantLookup.sessionExpired();
      }
      if (response.statusCode == 403) {
        return const MerchantLookup.missing();
      }
      if (response.statusCode != 200) {
        return const MerchantLookup.unavailable();
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return const MerchantLookup.unavailable();
      }
      final merchant = Merchant.tryParse(data['merchant']);
      if (merchant == null) return const MerchantLookup.unavailable();
      return MerchantLookup.found(merchant);
    } on TimeoutException {
      return const MerchantLookup.unavailable();
    } on SocketException {
      return const MerchantLookup.unavailable();
    } catch (_) {
      return const MerchantLookup.unavailable();
    }
  }

  Future<void> logout({String? token}) async {
    if (token == null || token.isEmpty) return;
    final url = Uri.parse('$_baseUrl/auth/logout');
    try {
      await _httpClient
          .post(
            url,
            headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/change-password');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const AuthResponse(
          isSuccess: false,
          message: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
          sessionExpired: true,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final rawToken = data['token'];
        final tokenValue = rawToken is String ? rawToken : '';
        return AuthResponse(
          isSuccess: true,
          message: data['message'] is String
              ? data['message'] as String
              : 'Contraseña actualizada correctamente',
          user: tokenValue.isEmpty
              ? null
              : User(name: '', email: '', token: tokenValue),
        );
      } else {
        return AuthResponse(
          isSuccess: false,
          message: data['message'] ?? 'Error al cambiar la contraseña',
        );
      }
    } on TimeoutException {
      return const AuthResponse(
        isSuccess: false,
        message: 'Tiempo de espera agotado. Verifique su conexión.',
      );
    } on SocketException {
      return const AuthResponse(
        isSuccess: false,
        message: 'No se pudo conectar con el servidor.',
      );
    } catch (e) {
      return const AuthResponse(
        isSuccess: false,
        message: 'Ocurrió un error inesperado. Reintente.',
      );
    }
  }
}
