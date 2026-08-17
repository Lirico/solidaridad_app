import '../../../core/formatters/amount_formatter.dart';
import 'sale_model.dart';

/// Genera el ticket térmico (HTML para `SdiPrinter.printHTML`) a partir de los
/// datos de una venta aprobada.
///
/// Es un port del `ReceiptFormatter` del POC Verifone, adaptado al modelo de
/// datos real de la app mobile (`OperationModel` / `SalesCompleted`).
class ReceiptFormatter {
  ReceiptFormatter._();

  static const String merchantName = 'GAS Terminal — Solidaridad';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String _statusLabel(PaymentResult result) {
    switch (result) {
      case PaymentResult.approved:
        return 'APROBADA';
      case PaymentResult.declined:
        return 'RECHAZADA';
      case PaymentResult.connectionError:
        return 'ERROR DE CONEXIÓN';
      case PaymentResult.voided:
        return 'ANULADA';
    }
  }

  /// Texto plano para previsualización / log.
  static String toPlainText(OperationModel op) {
    final buf = StringBuffer()
      ..writeln(merchantName)
      ..writeln('--------------------------------')
      ..writeln(_statusLabel(op.result))
      ..writeln('--------------------------------')
      ..writeln('Op:     ${op.id}')
      ..writeln('Fecha:  ${_formatDate(op.date)}')
      ..writeln('Hora:   ${_formatTime(op.date)}')
      ..writeln('Prod:   ${op.productLabel}')
      ..writeln('Monto:  ${formatAmount(op.amount)}')
      ..writeln('Tarjeta:${op.cardNumber}');
    if (op.userMessage != null && op.userMessage!.trim().isNotEmpty) {
      buf.writeln('Mensaje:${op.userMessage}');
    }
    buf
      ..writeln('--------------------------------')
      ..writeln('Gracias');
    return buf.toString();
  }

  /// HTML compacto para [SdiPrinter.printHTML] (térmica portrait).
  static String toHtml(OperationModel op) {
    final message =
        (op.userMessage != null && op.userMessage!.trim().isNotEmpty)
        ? '<div class="c">${_esc(op.userMessage!)}</div>'
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<style>
  * { font: 18px monospace, monospace; }
  body { margin: 0; padding: 8px; width: 100%; }
  .c { text-align: center; }
  .b { font-weight: bold; }
  .big { font-size: 22px; font-weight: bold; }
  table { width: 100%; border-collapse: collapse; }
  td { vertical-align: top; padding: 2px 0; }
  .l { text-align: left; width: 36%; }
  .r { text-align: right; word-break: break-all; }
  hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
</style>
</head>
<body>
  <div class="c b">${_esc(merchantName)}</div>
  <hr/>
  <div class="c big">${_esc(_statusLabel(op.result))}</div>
  $message
  <hr/>
  <table>
    <tr><td class="l">Op</td><td class="r">${_esc(op.id)}</td></tr>
    <tr><td class="l">Fecha</td><td class="r">${_esc(_formatDate(op.date))}</td></tr>
    <tr><td class="l">Hora</td><td class="r">${_esc(_formatTime(op.date))}</td></tr>
    <tr><td class="l">Producto</td><td class="r">${_esc(op.productLabel)}</td></tr>
    <tr><td class="l">Monto</td><td class="r b">${_esc(formatAmount(op.amount))}</td></tr>
    <tr><td class="l">Tarjeta</td><td class="r">${_esc(op.cardNumber)}</td></tr>
  </table>
  <hr/>
  <div class="c">Gracias</div>
  <br/><br/>
</body>
</html>
''';
  }

  static String _esc(String value) {
    final buf = StringBuffer();
    for (final rune in value.runes) {
      switch (rune) {
        case 0x26: // &
          buf.write('&');
          buf.write('amp;');
        case 0x3C: // <
          buf.write('&');
          buf.write('lt;');
        case 0x3E: // >
          buf.write('&');
          buf.write('gt;');
        case 0x22: // "
          buf.write('&');
          buf.write('quot;');
        default:
          buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }
}
