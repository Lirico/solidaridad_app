import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/balance_model.dart';

class BalanceRepository {
  final http.Client _httpClient;
  final String _baseUrl;

  BalanceRepository({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<BalanceResult> checkBalance({
    required String token,
    required String cardNumber,
    required String expirationDate,
    String entryMode = '012',
    String? track2,
  }) async {
    final url = Uri.parse('$_baseUrl/balance');

    final Map<String, dynamic> bodyPayload = {
      'card_number': cardNumber.replaceAll(' ', ''),
      'entry_mode': entryMode,
    };
    if (expirationDate.isNotEmpty) {
      bodyPayload['expiration_date'] = expirationDate;
    }
    if (track2 != null && track2.isNotEmpty) {
      bodyPayload['track2'] = track2;
    }

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
            body: jsonEncode(bodyPayload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        return const BalanceResult(
          status: BalanceStatus.connectionError,
          balances: [],
          message: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
          sessionExpired: true,
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String status = data['status'] as String? ?? '';
        if (status == 'APPROVED') {
          final List<dynamic> rawBalances =
              data['balances'] as List<dynamic>? ?? const [];
          final balances = rawBalances
              .map((item) => BalanceItem.fromJson(item as Map<String, dynamic>))
              .toList();
          return BalanceResult(
            status: BalanceStatus.approved,
            balances: balances,
            message: data['user_message'] as String? ?? 'Consulta de saldo exitosa',
          );
        }
        return BalanceResult(
          status: BalanceStatus.declined,
          balances: const [],
          message: data['user_message'] as String? ?? 'No se pudo consultar el saldo',
        );
      }

      return BalanceResult(
        status: BalanceStatus.declined,
        balances: const [],
        message: data['user_message'] as String? ?? 'No se pudo consultar el saldo',
      );
    } on TimeoutException {
      return const BalanceResult(
        status: BalanceStatus.connectionError,
        balances: [],
        message: 'Tiempo de espera agotado. Reintente.',
        connectionError: true,
      );
    } on SocketException {
      return const BalanceResult(
        status: BalanceStatus.connectionError,
        balances: [],
        message: 'No se pudo conectar con el servidor. Verifique su red.',
        connectionError: true,
      );
    } on HttpException {
      return const BalanceResult(
        status: BalanceStatus.connectionError,
        balances: [],
        message: 'Error de comunicación con el servidor. Reintente.',
        connectionError: true,
      );
    } catch (_) {
      return const BalanceResult(
        status: BalanceStatus.connectionError,
        balances: [],
        message: 'Ocurrió un error inesperado. Reintente.',
        connectionError: true,
      );
    }
  }
}
