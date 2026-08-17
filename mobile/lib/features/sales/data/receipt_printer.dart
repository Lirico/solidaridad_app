import 'dart:async';

import '../../../psdk/psdk_bridge.dart';
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
/// a [PsdkBridge.printHtml]. Reutiliza la misma lógica de espera de `sdiReady`
/// que usa `WaitingForCardScreen`.
class ReceiptPrinter {
  ReceiptPrinter({PsdkBridge? psdk}) : _psdk = psdk ?? PsdkBridge();

  final PsdkBridge _psdk;

  /// Imprime el ticket de [operation] en la térmica.
  ///
  /// Devuelve [PrintResult.success] si la impresión fue OK, o un
  /// [PrintResult.failure] con el motivo en caso contrario.
  Future<PrintResult> printTicket(OperationModel operation) async {
    try {
      // 1. Asegurar que el SDK esté inicializado y listo (sdiReady).
      final bool ready = await _ensureSdkReady();
      if (!ready) {
        return const PrintResult.failure(
          'No se pudo inicializar la impresora. Reintente.',
        );
      }

      // 2. Generar el HTML del ticket y enviarlo a la térmica.
      final String html = ReceiptFormatter.toHtml(operation);
      final Map<String, dynamic> result = await _psdk.printHtml(html);

      final bool ok = result['ok'] == true;
      if (ok) {
        return const PrintResult.success();
      }
      final String code = result['result'] as String? ?? 'UNKNOWN';
      return PrintResult.failure('La impresora no imprimió (código $code).');
    } catch (_) {
      return const PrintResult.failure(
        'Error al imprimir el ticket. Reintente.',
      );
    }
  }

  /// Inicializa el PaymentSDK y espera el evento `sdiReady`.
  ///
  /// `initialize()` es asíncrono: retorna de inmediato con `sdiReady=false` y
  /// el SDK recién queda listo cuando llega `handleStatus` con SUCCESS. Este
  /// método escucha [PsdkBridge.statusEvents] hasta que eso ocurra o se agote
  /// [timeoutSec].
  Future<bool> _ensureSdkReady({int timeoutSec = 20}) async {
    final status = await _psdk.getStatus();
    if (status['sdiReady'] == true) {
      return true;
    }

    await _psdk.initialize();

    final completer = Completer<bool>();
    StreamSubscription<Map<String, dynamic>>? sub;

    sub = _psdk.statusEvents.listen((event) {
      final bool ready = event['sdiReady'] == true || event['success'] == true;
      if (ready && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    try {
      return await completer.future.timeout(
        Duration(seconds: timeoutSec),
        onTimeout: () => false,
      );
    } finally {
      await sub.cancel();
    }
  }
}
