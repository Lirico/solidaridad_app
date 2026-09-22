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

/// Operaciones del terminal para armar el resumen del lote.
///
/// Usa `GET /v1/transactions` (el mismo endpoint del historial) paginando
/// porque la API devuelve hasta 100 ítems por página y ordena de más nuevo a
/// más viejo: alcanza con cortar la paginación cuando aparece una venta anterior
/// al inicio de la ventana del lote.
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

  /// Carga las operaciones desde el arranque de la ventana del lote.
  ///
  /// [after] es el último cierre local (si existe); si es `null`, la ventana
  /// arranca al inicio del día de [now].
  Future<BatchCloseLoadResult> loadOperations({
    required String token,
    DateTime? after,
    DateTime? now,
  }) async {
    final DateTime reference = now ?? DateTime.now();
    final DateTime cutoff =
        after ?? DateTime(reference.year, reference.month, reference.day);

    final List<OperationModel> collected = <OperationModel>[];
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

        collected.addAll(pageItems);
        offset += pageItems.length;

        // La lista viene de más nuevo a más viejo: si el último ítem ya quedó
        // fuera de la ventana, no hay nada más que sumar.
        final bool reachedCutoff = !pageItems.last.date.isAfter(cutoff);
        final bool loadedEverything =
            offset >= total || pageItems.length < pageSize;
        if (reachedCutoff || loadedEverything) break;

        // Quedan páginas dentro de la ventana: si se agotó el tope de
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
}
