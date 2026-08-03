import 'package:poc_verifone/receipt/receipt_data.dart';

/// Pure formatter: same [ReceiptData] → screen preview or thermal HTML.
class ReceiptFormatter {
  ReceiptFormatter._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String toPlainText(ReceiptData r) {
    final buf = StringBuffer()
      ..writeln(r.merchantName)
      ..writeln('--------------------------------')
      ..writeln(r.statusLabel)
      ..writeln(r.userMessage)
      ..writeln('--------------------------------')
      ..writeln('Op:     ${r.transactionNumber}')
      ..writeln('Fecha:  ${_formatDate(r.createdAt)}')
      ..writeln('Hora:   ${_formatTime(r.createdAt)}')
      ..writeln('Prod:   ${r.productLabel}')
      ..writeln('Monto:  ${r.amount}')
      ..writeln('Tarjeta:${r.maskedPan}');
    if (r.cardHolder != null && r.cardHolder!.trim().isNotEmpty) {
      buf.writeln('Titular:${r.cardHolder}');
    }
    buf
      ..writeln('--------------------------------')
      ..writeln('Gracias');
    return buf.toString();
  }

  /// Compact HTML for [SdiPrinter.printHTML] (portrait thermal).
  static String toHtml(ReceiptData r) {
    final holder = (r.cardHolder != null && r.cardHolder!.trim().isNotEmpty)
        ? '<tr><td class="l">Titular</td><td class="r">${_esc(r.cardHolder!)}</td></tr>'
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
  <div class="c b">${_esc(r.merchantName)}</div>
  <hr/>
  <div class="c big">${_esc(r.statusLabel)}</div>
  <div class="c">${_esc(r.userMessage)}</div>
  <hr/>
  <table>
    <tr><td class="l">Op</td><td class="r">${_esc(r.transactionNumber)}</td></tr>
    <tr><td class="l">Fecha</td><td class="r">${_esc(_formatDate(r.createdAt))}</td></tr>
    <tr><td class="l">Hora</td><td class="r">${_esc(_formatTime(r.createdAt))}</td></tr>
    <tr><td class="l">Producto</td><td class="r">${_esc(r.productLabel)}</td></tr>
    <tr><td class="l">Monto</td><td class="r b">${_esc(r.amount)}</td></tr>
    <tr><td class="l">Tarjeta</td><td class="r">${_esc(r.maskedPan)}</td></tr>
    $holder
  </table>
  <hr/>
  <div class="c">Gracias</div>
  <br/><br/>
</body>
</html>
''';
  }

  static String _esc(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
