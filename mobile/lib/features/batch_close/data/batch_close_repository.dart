import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../sales/domain/sale_model.dart';

/// Resultado de la carga de operaciones para el resumen del lote.
class BatchCloseLoadResult {
  final List<OperationModel> operations;

  /// `true` si se alcanzó el tope de páginas y el resumen puede estar incompleto.
  final bool isPartial;
  final bool sessionExpired;
  final bool connectionError;
  final String? errorMessage;

  const BatchCloseLoadResult({
    required this.operations,
    this.isPartial = false,
    this.sessionExpired = false,
    this.connectionError = false,
    this.errorMessage,
  });
}

/// Resultado de confirmar el corte administrativo del lote actual.
class BatchCloseSubmitResult {
  final List<OperationModel> operations;
  final int? batchCloseId;
  final bool sessionExpired;
  final bool connectionError;
  final String? errorMessage;

  const BatchCloseSubmitResult({
    this.operations = const <OperationModel>[],
    this.batchCloseId,
    this.sessionExpired = false,
    this.connectionError = false,
    this.errorMessage,
  });
}

/// Operaciones del terminal para armar el resumen del lote.
///
/// Usa `GET /v1/transactions` (el mismo endpoint del historial) paginando
/// porque la API devuelve hasta 100 ítems por página y ordena de más nuevo a
/// más viejo. La API ya limita el resultado al lote vigente, por eso se cargan
/// todas sus páginas.
///
/// A propósito **no** reutiliza `SalesRepository.fetchHistory`: ese método
/// convierte cualquier error en una lista vacía (antipatrón registrado como
/// G-P1-07) y esta pantalla no puede mostrar "0 ventas" si falló la red.
class BatchCloseRepository {
  /// Máximo de ítems por página que acepta `GET /v1/transactions`.
  static const int pageSize = 100;

  /// Tope de seguridad de páginas (10 × 100 = 1000 ventas por lote).
  static const int maxPages = 10;

  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _httpClient;
  final String _baseUrl;

  BatchCloseRepository({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Carga las operaciones de la ventana del lote.
  ///
  /// La API devuelve únicamente el lote administrativo actual: las
  /// transacciones ya cerradas no aparecen en este listado.
  Future<BatchCloseLoadResult> loadOperations({
    required String token,
  }) async {
    final List<OperationModel> collected = <OperationModel>[];

    // La paginación por offset sobre una lista que crece (ventas nuevas) puede
    // devolver un ítem ya cargado: se acumula sin repetir por Nº de operación.
    final Set<String> seenIds = <String>{};

    int offset = 0;
    bool isPartial = false;

    try {
      for (int page = 0; page < maxPages; page++) {
        final response = await _httpClient
            .get(
              Uri.parse(
                '$_baseUrl/transactions?limit=$pageSize&offset=$offset',
              ),
              headers: <String, String>{
                HttpHeaders.contentTypeHeader: 'application/json',
                HttpHeaders.authorizationHeader: 'Bearer $token',
              },
            )
            .timeout(_timeout);

        if (response.statusCode == 401) {
          return const BatchCloseLoadResult(
            operations: <OperationModel>[],
            sessionExpired: true,
          );
        }

        if (response.statusCode != 200) {
          return BatchCloseLoadResult(
            operations: const <OperationModel>[],
            connectionError: true,
            errorMessage:
                'No se pudo obtener el resumen del lote '
                '(HTTP ${response.statusCode}).',
          );
        }

        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items =
            body['items'] as List<dynamic>? ?? const <dynamic>[];
        final int total = (body['total'] as num?)?.toInt() ?? items.length;

        final List<OperationModel> pageItems = items
            .map(
              (item) => OperationModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        if (pageItems.isEmpty) break;

        // Si entró una venta entre dos páginas, el offset se corrió y la API
        // repite el último ítem de la página anterior: se descarta por Nº de
        // operación para no contar la venta (ni sus kg) dos veces.
        collected.addAll(pageItems.where((item) => seenIds.add(item.id)));
        offset += pageItems.length;

        final bool loadedEverything =
            offset >= total || pageItems.length < pageSize;
        if (loadedEverything) break;

        // Quedan páginas dentro del lote: si se agotó el tope de
        // seguridad, el resumen se marca parcial en lugar de ocultarse.
        if (page == maxPages - 1) isPartial = true;
      }

      return BatchCloseLoadResult(operations: collected, isPartial: isPartial);
    } on TimeoutException {
      return const BatchCloseLoadResult(
        operations: <OperationModel>[],
        connectionError: true,
        errorMessage: 'Tiempo de espera agotado. Reintente.',
      );
    } on SocketException {
      return const BatchCloseLoadResult(
        operations: <OperationModel>[],
        connectionError: true,
        errorMessage: 'No se pudo conectar con el servidor. Verifique su red.',
      );
    } on HttpException {
      return const BatchCloseLoadResult(
        operations: <OperationModel>[],
        connectionError: true,
        errorMessage: 'Error de comunicación con el servidor. Reintente.',
      );
    } on FormatException {
      return const BatchCloseLoadResult(
        operations: <OperationModel>[],
        connectionError: true,
        errorMessage: 'Respuesta inesperada del servidor. Reintente.',
      );
    } catch (_) {
      return const BatchCloseLoadResult(
        operations: <OperationModel>[],
        connectionError: true,
        errorMessage: 'Ocurrió un error inesperado. Reintente.',
      );
    }
  }

  /// Confirma el corte administrativo y devuelve sus operaciones para una
  /// futura impresión de comprobante.
  Future<BatchCloseSubmitResult> closeCurrentBatch({
    required String token,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/transactions/batch-close'),
            headers: <String, String>{
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
              'Idempotency-Key': idempotencyKey,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        return const BatchCloseSubmitResult(sessionExpired: true);
      }

      final Map<String, dynamic>? body = _tryDecodeObject(response.body);
      if (response.statusCode != 201) {
        return BatchCloseSubmitResult(
          connectionError: true,
          errorMessage:
              (body?['message'] as String?) ??
              'No se pudo cerrar el lote (HTTP ${response.statusCode}).',
        );
      }

      final List<dynamic> items = body?['items'] as List<dynamic>? ??
          const <dynamic>[];
      return BatchCloseSubmitResult(
        batchCloseId: (body?['batch_close_id'] as num?)?.toInt(),
        operations: items
            .map(
              (item) => OperationModel.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
    } on TimeoutException {
      return const BatchCloseSubmitResult(
        connectionError: true,
        errorMessage: 'Tiempo de espera agotado. Reintente.',
      );
    } on SocketException {
      return const BatchCloseSubmitResult(
        connectionError: true,
        errorMessage: 'No se pudo conectar con el servidor. Verifique su red.',
      );
    } on HttpException {
      return const BatchCloseSubmitResult(
        connectionError: true,
        errorMessage: 'Error de comunicación con el servidor. Reintente.',
      );
    } on FormatException {
      return const BatchCloseSubmitResult(
        connectionError: true,
        errorMessage: 'Respuesta inesperada del servidor. Reintente.',
      );
    } catch (_) {
      return const BatchCloseSubmitResult(
        connectionError: true,
        errorMessage: 'Ocurrió un error inesperado. Reintente.',
      );
    }
  }

  Map<String, dynamic>? _tryDecodeObject(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }
}
