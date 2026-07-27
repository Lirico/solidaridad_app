import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../domain/sale_model.dart';

/// Generates a pseudo-unique idempotency key.
///
/// In production, consider using the `uuid` package for guaranteed uniqueness.
/// This implementation combines a timestamp with random digits.
String _generateIdempotencyKey() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(99999);
  return '$timestamp-$random';
}

class SalesRepository {
  final http.Client _httpClient;
  final String _baseUrl;

  SalesRepository({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<ProductInfo>> fetchProducts({required String token}) async {
    final url = Uri.parse('$_baseUrl/products');
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

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => ProductInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return _defaultProducts();
    } catch (_) {
      return _defaultProducts();
    }
  }

  List<ProductInfo> _defaultProducts() {
    return const [
      ProductInfo(code: 'GARRAFA_10', label: 'Garrafa 10 kg'),
      ProductInfo(code: 'GARRAFA_15', label: 'Garrafa 15 kg'),
      ProductInfo(code: 'GARRAFA_30', label: 'Garrafa 30 kg'),
      ProductInfo(code: 'TUBO_45', label: 'Tubo 45 kg'),
      ProductInfo(code: 'GRANEL', label: 'Granel'),
    ];
  }

  Future<SaleResponse> registerSale({
    required String product,
    required String amount,
    required String cardNumber,
    required String cvv,
    required String expirationDate,
    required String token,
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

    final idempotencyKey = _generateIdempotencyKey();

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

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final bool approved = responseData['status'] == 'APPROVED';

        return SaleResponse(
          isApproved: approved,
          operationNumber: responseData['transaction_number'] ?? 'OP-UNKNOWN',
          message: responseData['user_message'] ?? 'Operación procesada',
          errorCode: '00',
        );
      } else {
        return SaleResponse(
          isApproved: false,
          operationNumber: responseData['transaction_number'] ?? '',
          message:
              responseData['user_message'] ??
              'Venta rechazada por la entidad emisora.',
          errorCode: '${response.statusCode}',
        );
      }
    } on TimeoutException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message:
            'Tiempo de espera agotado con el procesador de pagos (Timeout). Reintente.',
        errorCode: '99',
        connectionError: true,
      );
    } on SocketException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message:
            'No se pudo establecer conexión con el servidor de AWS. Verifique su red.',
        errorCode: 'CONN_ERR',
        connectionError: true,
      );
    } on HttpException {
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message: 'Error en el protocolo de comunicación con la API.',
        errorCode: 'HTTP_ERR',
        connectionError: true,
      );
    } catch (e) {
      return SaleResponse(
        isApproved: false,
        operationNumber: '',
        message: 'Error inesperado: ${e.toString()}',
        errorCode: 'UNKNOWN',
      );
    }
  }
}
