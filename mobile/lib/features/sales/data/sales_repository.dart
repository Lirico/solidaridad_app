import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../domain/sale_model.dart';

/// Thrown when the API returns 401 (token expired/invalid).
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

/// Fallo al cargar catálogo o historial. [message] es el texto para el operador.
class DataLoadException implements Exception {
  final String message;

  const DataLoadException(this.message);

  @override
  String toString() => message;
}

const _loadTimeoutMessage = 'Tiempo de espera agotado. Verifique su conexión.';
const _loadNetworkMessage =
    'No se pudo conectar con el servidor. Verifique su red.';
const _loadHttpMessage = 'Error de comunicación con el servidor. Reintente.';
const _loadRejectedMessage = 'No se pudieron cargar los datos. Reintente.';
const _loadUnexpectedMessage = 'Ocurrió un error inesperado. Reintente.';

/// Generates a pseudo-unique idempotency key.
///
/// In production, consider using the `uuid` package for guaranteed uniqueness.
/// This implementation combines a timestamp with random digits.
///
/// La venta genera la clave una sola vez (al abrir la revisión) y la reenvía
/// en cada intento. La anulación sigue generando una clave por request.
String generateIdempotencyKey() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(99999);
  return '$timestamp-$random';
}

/// Texto que ve el operador. Un 201 trae `user_message`; un 400/409 trae
/// `message`. Si no hay ninguno, se usa [fallback].
String apiUserMessage(Map<String, dynamic> data, String fallback) {
  for (final key in ['user_message', 'message']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

class SalesRepository {
  final http.Client _httpClient;
  final String _baseUrl;

  SalesRepository({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<http.Response> _authorizedGet(Uri url, String token) async {
    try {
      final response = await _httpClient
          .get(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        throw const SessionExpiredException();
      }
      return response;
    } on SessionExpiredException {
      rethrow;
    } on TimeoutException {
      throw const DataLoadException(_loadTimeoutMessage);
    } on SocketException {
      throw const DataLoadException(_loadNetworkMessage);
    } on HttpException {
      throw const DataLoadException(_loadHttpMessage);
    } on http.ClientException {
      throw const DataLoadException(_loadNetworkMessage);
    } catch (_) {
      throw const DataLoadException(_loadUnexpectedMessage);
    }
  }

  Future<List<ProductInfo>> fetchProducts({required String token}) async {
    final url = Uri.parse('$_baseUrl/products');
    try {
      final response = await _authorizedGet(url, token);
      if (response.statusCode != 200) {
        throw const DataLoadException(_loadRejectedMessage);
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => ProductInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    } on SessionExpiredException {
      rethrow;
    } on DataLoadException {
      rethrow;
    } catch (_) {
      throw const DataLoadException(_loadUnexpectedMessage);
    }
  }

  Future<VoidResult> voidTransaction({
    required String token,
    required String transactionNumber,
    required String cardNumber,
    String? expirationDate,
  }) async {
    final url = Uri.parse('$_baseUrl/transactions/$transactionNumber/void');

    final Map<String, dynamic> bodyPayload = {
      'card_number': cardNumber.replaceAll(' ', ''),
    };
    if (expirationDate != null && expirationDate.isNotEmpty) {
      bodyPayload['expiration_date'] = expirationDate;
    }

    final idempotencyKey = generateIdempotencyKey();

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
              'Idempotency-Key': idempotencyKey,
            },
            body: jsonEncode(bodyPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        throw const SessionExpiredException();
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String status = (responseData['status'] as String? ?? '')
            .toUpperCase();
        final String reason = (responseData['reason'] as String? ?? '')
            .toUpperCase();
        final String message =
            responseData['user_message'] as String? ?? 'Operación procesada';

        if (status == 'VOIDED') {
          return VoidResult.voided(message: message);
        }
        if ((status == 'FAILED' && reason == 'UNDER_REVIEW') ||
            status == 'UNDER_REVIEW') {
          return VoidResult.underReview(message: message);
        }
        if (status == 'FAILED') {
          return VoidResult.connectionFailure(message: message);
        }
        if (status == 'UNKNOWN') {
          return VoidResult.unknown(message: message);
        }
        return VoidResult.declined(message: message);
      }

      return VoidResult.declined(
        message: apiUserMessage(
          responseData,
          'Anulación rechazada por la entidad emisora.',
        ),
      );
    } on SessionExpiredException {
      rethrow;
    } on TimeoutException {
      return const VoidResult.connectionFailure(
        message:
            'Tiempo de espera agotado con el procesador de pagos (Timeout). Reintente.',
      );
    } on SocketException {
      return const VoidResult.connectionFailure(
        message:
            'No se pudo establecer conexión con el servidor. Verifique su red.',
      );
    } on HttpException {
      return const VoidResult.connectionFailure(
        message: 'Error en el protocolo de comunicación con la API.',
      );
    } catch (e) {
      return VoidResult.declined(message: 'Error inesperado: ${e.toString()}');
    }
  }

  Future<List<OperationModel>> fetchHistory({
    required String token,
    int limit = 20,
    int offset = 0,
  }) async {
    final url = Uri.parse('$_baseUrl/transactions?limit=$limit&offset=$offset');
    try {
      final response = await _authorizedGet(url, token);
      if (response.statusCode != 200) {
        throw const DataLoadException(_loadRejectedMessage);
      }
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = body['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => OperationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on SessionExpiredException {
      rethrow;
    } on DataLoadException {
      rethrow;
    } catch (_) {
      throw const DataLoadException(_loadUnexpectedMessage);
    }
  }

  /// Consulta una autorización ya creada. Nunca envía otro `POST /transactions`,
  /// por lo que es segura para continuar una venta tras perder la respuesta
  /// inicial o reiniciar la aplicación.
  Future<SaleResponse> getSaleStatus({
    required String token,
    required String transactionNumber,
  }) async {
    final url = Uri.parse('$_baseUrl/transactions/$transactionNumber');
    try {
      final response = await _authorizedGet(url, token);
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw const DataLoadException(_loadRejectedMessage);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _saleResponseFromJson(data);
    } on SessionExpiredException {
      rethrow;
    } on DataLoadException {
      rethrow;
    } on FormatException {
      throw const DataLoadException(_loadUnexpectedMessage);
    }
  }

  Future<SaleResponse> registerSale({
    required String product,
    required String amount,
    required String cardNumber,
    required String cvv,
    required String expirationDate,
    required String token,
    required String idempotencyKey,
  }) async {
    final url = Uri.parse('$_baseUrl/transactions');

    final Map<String, dynamic> bodyPayload = {
      'product': product,
      'amount': amount,
      'card_number': cardNumber.replaceAll(' ', ''),
      'cvv': cvv,
    };
    if (expirationDate.isNotEmpty) {
      bodyPayload['expiration_date'] = expirationDate;
    }

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
              'Idempotency-Key': idempotencyKey,
            },
            body: jsonEncode(bodyPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const SaleResponse(
          isApproved: false,
          operationNumber: '',
          message: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
          errorCode: '401',
          sessionExpired: true,
        );
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final String saleMessage =
          (responseData['user_message'] ?? responseData['message'] ?? '')
              .toString();
      debugPrint(
        'sale response status=${response.statusCode} message=$saleMessage',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        return _saleResponseFromJson(responseData);
      } else {
        return SaleResponse(
          isApproved: false,
          operationNumber: responseData['transaction_number'] ?? '',
          message: apiUserMessage(
            responseData,
            'Venta rechazada por la entidad emisora.',
          ),
          errorCode: '${response.statusCode}',
        );
      }
    } on TimeoutException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message:
            'Tiempo de espera agotado con el procesador de pagos. Reintente.',
        errorCode: '99',
        connectionError: true,
      );
    } on SocketException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message:
            'No se pudo establecer conexión con el servidor. Verifique su red.',
        errorCode: 'CONN_ERR',
        connectionError: true,
      );
    } on HttpException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message: 'Error de comunicación con el servidor. Reintente.',
        errorCode: 'HTTP_ERR',
        connectionError: true,
      );
    } catch (e) {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message: 'Ocurrió un error inesperado. Reintente.',
        errorCode: 'UNKNOWN',
      );
    }
  }

  SaleResponse _saleResponseFromJson(Map<String, dynamic> data) {
    final rawStatus = (data['status'] as String? ?? '').toUpperCase();
    final SaleAuthorizationStatus authorizationStatus;
    switch (rawStatus) {
      case 'APPROVED':
        authorizationStatus = SaleAuthorizationStatus.approved;
      case 'DECLINED':
        authorizationStatus = SaleAuthorizationStatus.declined;
      case 'PENDING':
        authorizationStatus = SaleAuthorizationStatus.pending;
      case 'FAILED':
      case 'NOT_SENT':
      case 'INDETERMINATE':
      default:
        authorizationStatus = SaleAuthorizationStatus.failed;
    }

    final rawReason = (data['reason'] as String? ?? '').toUpperCase();
    final PendingSaleReason? pendingReason;
    switch (rawReason) {
      case 'PROCESSING':
        pendingReason = PendingSaleReason.processing;
      case 'UNDER_REVIEW':
        pendingReason = PendingSaleReason.underReview;
      default:
        pendingReason = null;
    }

    return SaleResponse(
      isApproved: authorizationStatus == SaleAuthorizationStatus.approved,
      operationNumber: data['transaction_number'] as String? ?? '',
      message: apiUserMessage(data, 'Operación procesada'),
      errorCode: authorizationStatus == SaleAuthorizationStatus.approved
          ? '00'
          : rawStatus,
      authorizationStatus: authorizationStatus,
      pendingReason: pendingReason,
      pollAfterSeconds: data['poll_after_seconds'] as int?,
      mayStartNewSale: data['may_start_new_sale'] as bool? ?? true,
    );
  }
}
