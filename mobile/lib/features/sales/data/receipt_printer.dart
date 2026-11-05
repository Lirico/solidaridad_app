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
  /// llamar a la térmica, apaga el SDK y vuelve a crearlo. Un código de
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
          await _releaseForRetry();
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
        if (error.code != 'PSDK_NOT_READY') {
          return const PrintResult.failure(
            'Error al imprimir el ticket. Reintente.',
          );
        }
        await _releaseForRetry();
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

  /// Apaga el SDK entre arranques fallidos para que el siguiente `initialize`
  /// cree uno nuevo. Un tearDown fallido no debe tapar el reintento.
  Future<void> _releaseForRetry() async {
    try {
      await _psdk.tearDown();
    } catch (_) {}
  }
}
