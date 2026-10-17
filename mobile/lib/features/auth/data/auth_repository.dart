import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/device/device_identity_service.dart';
import '../domain/auth_model.dart';

class AuthRepository {
  final http.Client _httpClient;
  final String _baseUrl;
  final DeviceIdentityService _deviceIdentity;

  AuthRepository({
    http.Client? httpClient,
    String? baseUrl,
    DeviceIdentityService? deviceIdentity,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _deviceIdentity = deviceIdentity ?? DeviceIdentityService();

  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final identity = await _deviceIdentity.resolve();

    final Map<String, dynamic> body = {
      'username': usernameOrEmail,
      'password': password,
      'installation_id': identity.installationId,
      // Contrato fijo: las tres claves siempre presentes. Cuando no hay dato
      // real (terminal sin provisionar / sin hardware) van como cadena vacía.
      'serial_number': identity.serialNumber ?? '',
      'logical_device_id': identity.logicalDeviceId ?? '',
    };

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode(body),
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

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'installation_id': _deviceIdentity.installationId,
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
