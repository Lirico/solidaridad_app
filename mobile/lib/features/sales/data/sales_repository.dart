import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/sale_model.dart';

class SalesRepository {
  final http.Client _httpClient;
  // TODO: Mover a un archivo de configuración de ambientes (.env) cuando configuren AWS
  final String _baseUrl = 'https://api.solidaridad-prod.aws.com/v1';

  SalesRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<SaleResponse> registerGasSale({
    required String currency,
    required double amount,
    required String cardNumber,
    required String cardHolder,
    required String token, // Token de sesión de la Fase 0
  }) async {
    final url = Uri.parse('$_baseUrl/sales/gas');

    final Map<String, dynamic> bodyPayload = {
      'species_currency': currency,
      'amount': amount,
      'card_number': cardNumber.replaceAll(
        ' ',
        '',
      ), // Quitamos la máscara visual
      'card_holder': cardHolder,
      'terminal_origin': 'VIRTUAL_POS_01', // ID de terminal asociada
    };

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
          .timeout(
            const Duration(seconds: 15),
          ); // Control de Timeout que pide el instructivo

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Operación procesada de forma exitosa por el Gateway ISO
        final bool approved = responseData['status'] == 'APPROVED';

        return SaleResponse(
          isApproved: approved,
          operationNumber: responseData['operation_number'] ?? 'OP-UNKNOWN',
          message: responseData['user_message'] ?? 'Operación procesada',
          errorCode: responseData['error_code'] ?? '00',
        );
      } else {
        // Errores de negocio reportados por el Backend/Procesador (ej: Fondos insuficientes)
        return SaleResponse(
          isApproved: false,
          operationNumber: responseData['operation_number'] ?? '',
          message:
              responseData['user_message'] ??
              'Venta rechazada por la entidad emisora.',
          errorCode: responseData['error_code'] ?? '${response.statusCode}',
        );
      }
    } on TimeoutException {
      // Tiempo de espera agotado = error de conectividad
      return const SaleResponse(
        isApproved: false,
        operationNumber: '',
        message:
            'Tiempo de espera agotado con el procesador de pagos (Timeout). Reintente.',
        errorCode: '99',
        connectionError: true,
      );
    } on SocketException {
      // Error de conectividad física o DNS
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
      // Catch genérico final
      return SaleResponse(
        isApproved: false,
        operationNumber: '',
        message: 'Error inesperado: ${e.toString()}',
        errorCode: 'UNKNOWN',
      );
    }
  }
}
