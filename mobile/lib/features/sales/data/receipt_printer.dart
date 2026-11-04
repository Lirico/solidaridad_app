import '../../../psdk/psdk_bridge.dart';
import '../../../psdk/psdk_card_reader.dart';
import '../domain/receipt_formatter.dart';
import '../domain/sale_model.dart';
import 'receipt_defaults_repository.dart';

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
/// pantallas de lectura de banda. Un `success` del SDK sin `sdiReady` no
/// alcanza: la térmica se usa recién cuando el manager de SDI está listo.
class ReceiptPrinter {
  ReceiptPrinter({
    PsdkBridge? psdk,
    PsdkCardReader? reader,
    ReceiptDefaultsRepository? defaultsRepository,
  }) : _psdk = psdk ?? PsdkBridge(),
       _defaults = defaultsRepository ?? ReceiptDefaultsRepository() {
    _reader = reader ?? PsdkCardReader(psdk: _psdk);
  }

  final PsdkBridge _psdk;
  final ReceiptDefaultsRepository _defaults;
  late final PsdkCardReader _reader;

  /// Imprime el ticket de [operation] en la térmica.
  ///
  /// Devuelve [PrintResult.success] si la impresión fue OK, o un
  /// [PrintResult.failure] con el motivo en caso contrario.
  Future<PrintResult> printTicket(OperationModel operation) async {
    try {
      // 1. Asegurar que el SDK esté inicializado y listo (sdiReady).
      final bool ready = await _reader.ensureReady(initializeIfNeeded: true);
      if (!ready) {
        return const PrintResult.failure(
          'No se pudo inicializar la impresora. Reintente.',
        );
      }

      // 2. Generar el HTML del ticket y enviarlo a la térmica.
      final defaults = await _defaults.load();
      final String html = ReceiptFormatter.toHtml(operation, defaults);
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
}
