import '../../../core/formatters/amount_formatter.dart';
import 'receipt_defaults.dart';
import 'sale_model.dart';

/// Genera el ticket térmico (HTML para `SdiPrinter.printHTML`) a partir de los
/// datos de una venta y del perfil [ReceiptDefaults].
///
/// Es un port del `ReceiptFormatter` del POC Verifone, adaptado al modelo de
/// datos real de la app mobile (`OperationModel` / `SalesCompleted`).
class ReceiptFormatter {
  ReceiptFormatter._();

  static const String terminalId = String.fromEnvironment(
    'INSTALLATION_ID',
    defaultValue: '05000001',
  );

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
      case PaymentResult.pending:
        return 'EN PROCESO';
      case PaymentResult.underReview:
        return 'COMPROBANTE DE VERIFICACIÓN';
      case PaymentResult.failed:
        return 'ERROR DE AUTORIZACIÓN';
      case PaymentResult.connectionError:
        return 'ERROR DE CONEXIÓN';
      case PaymentResult.voided:
        return 'ANULADA';
    }
  }

  /// Venta para una operación. Anulación solo cuando el resultado es un void.
  static String operationTypeLabel(PaymentResult result) {
    if (result == PaymentResult.voided) return 'Anulación';
    return 'Venta';
  }

  /// Texto plano para previsualización / log.
  static String toPlainText(OperationModel op, ReceiptDefaults defaults) {
    final date = _formatDate(op.date);
    final time = _formatTime(op.date);
    final type = operationTypeLabel(op.result);
    final buf = StringBuffer()
      ..writeln(_statusLabel(op.result));
    if (op.result == PaymentResult.underReview) {
      buf
        ..writeln(
          'No cobre nuevamente: podría producirse un cobro duplicado.',
        )
        ..writeln('Verifique esta referencia con casa central.');
    }
    buf
      ..writeln('--------------------------------')
      ..writeln('$date  ${defaults.issuerName}  $time')
      ..writeln(type)
      ..writeln(defaults.establishmentName)
      ..writeln(defaults.establishmentAddress)
      ..writeln(defaults.establishmentCuit)
      ..writeln('--------------------------------')
      ..writeln('Cód. establecimiento: ${defaults.establishmentCode}')
      ..writeln('Cupón: ${defaults.couponNumber}')
      ..writeln('Lote: ${defaults.batchNumber}')
      ..writeln('Terminal: $terminalId')
      ..writeln('Tarjeta: ${maskPan(op.cardNumber)}')
      ..writeln('Autorización: ${defaults.authorizationCode}')
      ..writeln('Op: ${op.id}')
      ..writeln('Producto: ${op.productLabel}')
      ..writeln('Importe: ${formatAmount(op.amount)}')
      ..writeln('Moneda: ${defaults.currency}')
      ..writeln('Cuotas: ${defaults.installments}')
      ..writeln('Plan: ${defaults.installmentPlan}');
    if (op.result == PaymentResult.voided) {
      buf.writeln('Cargo original: ${defaults.originalChargeNumber}');
    }
    final message = op.userMessage?.trim() ?? '';
    if (message.isNotEmpty) {
      buf.writeln('Mensaje: $message');
    }
    buf
      ..writeln('--------------------------------')
      ..writeln('Gracias');
    return buf.toString();
  }

  /// HTML compacto para [SdiPrinter.printHTML] (térmica portrait).
  static String toHtml(OperationModel op, ReceiptDefaults defaults) {
    final lines = <String>[
      _line('Cód. establecimiento', defaults.establishmentCode),
      _line('Cupón', defaults.couponNumber),
      _line('Lote', defaults.batchNumber),
      _line('Terminal', terminalId),
      _line('Tarjeta', maskPan(op.cardNumber)),
      _line('Autorización', defaults.authorizationCode),
      _line('Op', op.id),
      _line('Producto', op.productLabel),
      _line('Importe', formatAmount(op.amount), emphasize: true),
      _line('Moneda', defaults.currency),
      _line('Cuotas', defaults.installments),
      _line('Plan', defaults.installmentPlan),
    ];
    if (op.result == PaymentResult.voided) {
      lines.add(_line('Cargo original', defaults.originalChargeNumber));
    }
    final message = op.userMessage?.trim() ?? '';
    if (message.isNotEmpty) {
      lines.add(_line('Mensaje', message));
    }
    final verificationWarning = op.result == PaymentResult.underReview
        ? '<div class="c">No cobre nuevamente: podría producirse un cobro duplicado.<br/>Verifique esta referencia con casa central.</div>'
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
  td { vertical-align: top; padding: 2px 0; width: 33%; }
  .l { text-align: left; }
  .r { text-align: right; }
  .detail { text-align: left; padding-top: 8px; }
  hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
</style>
</head>
<body>
  <div class="c big">${_esc(_statusLabel(op.result))}</div>
  $verificationWarning
  <hr/>
  <table>
    <tr>
      <td class="l">${_esc(_formatDate(op.date))}</td>
      <td class="c b">${_esc(defaults.issuerName)}<br/><span>${_esc(operationTypeLabel(op.result))}</span></td>
      <td class="r">${_esc(_formatTime(op.date))}</td>
    </tr>
  </table>
  <div class="c b">${_esc(defaults.establishmentName)}</div>
  <div class="c">${_esc(defaults.establishmentAddress)}</div>
  <div class="c">${_esc(defaults.establishmentCuit)}</div>
  <div class="detail">
    ${lines.join('\n    ')}
  </div>
  <hr/>
  <div class="c">Gracias</div>
  <br/><br/>
</body>
</html>
''';
  }

  static String _line(String label, String value, {bool emphasize = false}) {
    final css = emphasize ? ' class="b"' : '';
    return '<div$css>${_esc(label)}: ${_esc(value)}</div>';
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

  /// Últimos 4 visibles, 5 centrales enmascarados y el resto visible.
  ///
  /// Un PAN de al menos 9 dígitos queda `prefijo + ***** + últimos 4`. Si ya
  /// viene enmascarado, o solo quedan los últimos 4 (historial de la API),
  /// no se reconstruye el número.
  static String maskPan(String value) {
    if (value.contains('*')) return value;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 9) {
      final prefixLength = digits.length - 9;
      return '${digits.substring(0, prefixLength)}*****${digits.substring(digits.length - 4)}';
    }
    if (digits.length >= 4) {
      return '•••• ${digits.substring(digits.length - 4)}';
    }
    return '•••• ----';
  }
}
