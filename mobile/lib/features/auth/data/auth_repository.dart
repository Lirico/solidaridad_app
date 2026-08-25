import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/terminal/terminal_provisioner.dart';
import '../domain/auth_model.dart';

class AuthRepository {
  final http.Client _httpClient;
  final String _baseUrl;
  final TerminalProvisioner _provisioner;

  AuthRepository({
    http.Client? httpClient,
    String? baseUrl,
    TerminalProvisioner? provisioner,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _provisioner = provisioner ?? TerminalProvisioner();

  /// Devuelve el `installation_id` real del terminal (resuelto y persistido
  /// por el backend), o `null` si aún no se provisionó.
  Future<String?> _resolveInstallationId() async {
    return _provisioner.getInstallationId();
  }

  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final installationId = await _resolveInstallationId();

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'username': usernameOrEmail,
              'password': password,
              'installation_id': installationId,
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
    final installationId = await _resolveInstallationId();

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'installation_id': installationId,
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

  Future<void> logout() async {
    // En un entorno real aquí se invalidaría el token en backend
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
        return const AuthResponse(
          isSuccess: true,
          message: 'Contraseña actualizada correctamente',
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
