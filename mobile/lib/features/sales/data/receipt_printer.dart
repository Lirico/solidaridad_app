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

  const PrintResult.success({this.message = 'Ticket impreso'}) : ok = true;

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
  /// Una venta aprobada imprime el original del comercio y después la copia
  /// del cliente. El resto de los resultados imprime un solo ticket.
  ///
  /// Devuelve [PrintResult.success] si la impresión fue OK, o un
  /// [PrintResult.failure] con el motivo en caso contrario. Si el original
  /// salió y la copia no, el mensaje lo indica y no se reintenta sola la copia.
  Future<PrintResult> printTicket(OperationModel operation) async {
    try {
      // 1. Asegurar que el SDK esté inicializado y listo (sdiReady).
      final bool ready = await _reader.ensureReady(initializeIfNeeded: true);
      if (!ready) {
        return const PrintResult.failure(
          'No se pudo inicializar la impresora. Reintente.',
        );
      }

      // 2. Generar el HTML y enviarlo a la térmica.
      // Una venta aprobada imprime original y después copia.
      final defaults = await _defaults.load();
      if (operation.result == PaymentResult.approved) {
        final PrintResult original = await _printHtml(
          ReceiptFormatter.toHtml(
            operation,
            defaults,
            copy: ReceiptCopy.merchant,
          ),
        );
        if (!original.ok) return original;

        try {
          final PrintResult copy = await _printHtml(
            ReceiptFormatter.toHtml(
              operation,
              defaults,
              copy: ReceiptCopy.customer,
            ),
          );
          if (!copy.ok) {
            return const PrintResult.failure(
              'Se imprimió el original. La copia no salió.',
            );
          }
        } catch (_) {
          return const PrintResult.failure(
            'Se imprimió el original. La copia no salió.',
          );
        }
        return const PrintResult.success(
          message: 'Original y copia impresos',
        );
      }

      return _printHtml(ReceiptFormatter.toHtml(operation, defaults));
    } catch (_) {
      return const PrintResult.failure(
        'Error al imprimir el ticket. Reintente.',
      );
    }
  }

  Future<PrintResult> _printHtml(String html) async {
    final Map<String, dynamic> result = await _psdk.printHtml(html);
    final bool ok = result['ok'] == true;
    if (ok) {
      return const PrintResult.success();
    }
    final String code = result['result'] as String? ?? 'UNKNOWN';
    return PrintResult.failure('La impresora no imprimió (código $code).');
  }
}
