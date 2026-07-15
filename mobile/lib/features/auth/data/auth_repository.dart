import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/auth_model.dart';

class AuthRepository {
  final http.Client _httpClient;
  final String _baseUrl = 'https://api.solidaridad-prod.aws.com/v1';

  // Mock: conjunto de usuarios que ya cambiaron su contraseña
  static final Set<String> _usersWithPasswordChanged = {};

  AuthRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Marca a un usuario como que ya cambió su contraseña (mock)
  static void markPasswordAsChanged(String username) {
    _usersWithPasswordChanged.add(username.toLowerCase());
  }

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
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final String email = (data['email'] ?? '').toString().toLowerCase();
        final bool mustChange = !_usersWithPasswordChanged.contains(email);

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
      return AuthResponse(
        isSuccess: false,
        message: 'Error inesperado: ${e.toString()}',
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
      return AuthResponse(
        isSuccess: false,
        message: 'Error inesperado: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/change-password');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

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
      return AuthResponse(
        isSuccess: false,
        message: 'Error inesperado: ${e.toString()}',
      );
    }
  }
}
