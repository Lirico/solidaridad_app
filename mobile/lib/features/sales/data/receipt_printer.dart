import 'package:flutter/services.dart';

import '../../../psdk/psdk_bridge.dart';
import '../../../psdk/psdk_card_reader.dart';
import '../domain/receipt_formatter.dart';
import '../domain/sale_model.dart';

/// Resultado de una impresión de ticket.
class PrintResult {
  final bool ok;
  final String message;

  const PrintResult({required this.ok, required this.message});

  const PrintResult.success() : ok = true, message = 'Ticket impreso';

  const PrintResult.failure(this.message) : ok = false;
}

/// Imprime el ticket térmico en la terminal Verifone V660P.
///
/// Encapsula la inicialización del PaymentSDK (si no está listo) y la llamada
/// a [PsdkBridge.printHtml]. La espera de `sdiReady` (con el guard de
/// race-condition) vive en [PsdkCardReader.ensureReady], compartida con las
/// pantallas de lectura de banda.
class ReceiptPrinter {
  ReceiptPrinter({PsdkBridge? psdk, PsdkCardReader? reader})
    : _psdk = psdk ?? PsdkBridge() {
    _reader = reader ?? PsdkCardReader(psdk: _psdk);
  }

  final PsdkBridge _psdk;
  late final PsdkCardReader _reader;

  /// Imprime el ticket de [operation] en la térmica.
  ///
  /// Reintenta solo el arranque, hasta [initAttempts] veces, con
  /// [initRetryDelay] entre intentos. Cada espera de `sdiReady` dura como
  /// máximo [readyTimeoutSec]. Si [PsdkCardReader.ensureReady] no ve el
  /// manager, o si [PsdkBridge.printHtml] responde `PSDK_NOT_READY` antes de
  /// llamar a la térmica, cierra la sesión antes de reinicializarla. Un código de
  /// `printHTML` ya ejecutado no se reintenta.
  ///
  /// Devuelve [PrintResult.success] si la impresión fue OK, o un
  /// [PrintResult.failure] con el motivo en caso contrario.
  Future<PrintResult> printTicket(
    OperationModel operation, {
    int initAttempts = 3,
    Duration initRetryDelay = const Duration(milliseconds: 400),
    int readyTimeoutSec = 8,
  }) async {
    final int attempts = initAttempts < 1 ? 1 : initAttempts;
    final String html = ReceiptFormatter.toHtml(operation);

    for (var attempt = 0; attempt < attempts; attempt++) {
      final bool willRetry = attempt < attempts - 1;
      try {
        final bool ready = await _reader.ensureReady(
          initializeIfNeeded: true,
          timeoutSec: readyTimeoutSec,
        );
        if (!ready) {
          if (!await _releaseForRetry()) {
            return const PrintResult.failure(
              'No se pudo recuperar la conexión de la impresora.',
            );
          }
          if (willRetry) {
            await Future<void>.delayed(initRetryDelay);
            continue;
          }
          return const PrintResult.failure(
            'No se pudo inicializar la impresora. Reintente.',
          );
        }

        final Map<String, dynamic> result = await _psdk.printHtml(html);
        if (result['ok'] == true) {
          return const PrintResult.success();
        }
        final String code = result['result'] as String? ?? 'UNKNOWN';
        return PrintResult.failure('La impresora no imprimió (código $code).');
      } on PlatformException catch (error) {
        if (error.code != 'PSDK_NOT_READY' &&
            error.code != 'PSDK_INVALID_STATE' &&
            error.code != 'PSDK_INIT_FAILED') {
          return const PrintResult.failure(
            'Error al imprimir el ticket. Reintente.',
          );
        }
        if (!await _releaseForRetry()) {
          return const PrintResult.failure(
            'No se pudo recuperar la conexión de la impresora.',
          );
        }
        if (willRetry) {
          await Future<void>.delayed(initRetryDelay);
          continue;
        }
        return const PrintResult.failure(
          'No se pudo inicializar la impresora. Reintente.',
        );
      } catch (_) {
        return const PrintResult.failure(
          'Error al imprimir el ticket. Reintente.',
        );
      }
    }

    return const PrintResult.failure(
      'No se pudo inicializar la impresora. Reintente.',
    );
  }

  /// Espera el cierre confirmado antes de reintentar la sesión compartida.
  Future<bool> _releaseForRetry() async {
    try {
      await _psdk.tearDown().timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }
}
