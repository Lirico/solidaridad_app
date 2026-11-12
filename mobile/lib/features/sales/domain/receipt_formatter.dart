import '../../../core/formatters/amount_formatter.dart';
import 'receipt_defaults.dart';
import 'sale_model.dart';

/// Ticket único, original del comercio o copia del cliente.
///
/// [ReceiptCopy.single] no agrega leyenda. Una venta aprobada imprime
/// [ReceiptCopy.merchant] y después [ReceiptCopy.customer].
enum ReceiptCopy { single, merchant, customer }

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

  static String _statusLabel(OperationModel op) {
    switch (op.result) {
      case PaymentResult.approved:
        return 'Aprobada';
      case PaymentResult.declined:
        final code = op.responseCode?.trim() ?? '';
        if (code.isEmpty) return 'Denegada';
        return 'Denegada ($code)';
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
  static String toPlainText(
    OperationModel op,
    ReceiptDefaults defaults, {
    ReceiptCopy copy = ReceiptCopy.single,
  }) {
    final date = _formatDate(op.date);
    final time = _formatTime(op.date);
    final type = operationTypeLabel(op.result);
    final buf = StringBuffer()
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
    final declined = op.result == PaymentResult.declined;
    if (message.isNotEmpty && !declined) {
      buf.writeln('Mensaje: $message');
    }
    buf.writeln(_statusLabel(op));
    if (declined && message.isNotEmpty) {
      buf.writeln(message);
    }
    if (copy == ReceiptCopy.customer) {
      buf.writeln('COPIA CLIENTE');
    }
    if (op.result == PaymentResult.underReview) {
      buf.writeln('No cobre nuevamente: podría producirse un cobro duplicado.');
      buf.writeln('Verifique esta referencia con casa central.');
    }
    if (!declined && copy != ReceiptCopy.customer) {
      buf.writeln('Firma: ${'.' * 48}');
      if (copy == ReceiptCopy.merchant) {
        buf.writeln('ORIGINAL COMERCIO');
      }
    }
    return buf.toString();
  }

  /// HTML compacto para [SdiPrinter.printHTML] (térmica portrait).
  static String toHtml(
    OperationModel op,
    ReceiptDefaults defaults, {
    ReceiptCopy copy = ReceiptCopy.single,
  }) {
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
    final declined = op.result == PaymentResult.declined;
    if (message.isNotEmpty && !declined) {
      lines.add(_line('Mensaje', message));
    }
    final customerLegend = copy == ReceiptCopy.customer
        ? '<div class="c b">COPIA CLIENTE</div>'
        : '';
    final verificationWarning = op.result == PaymentResult.underReview
        ? '<div class="c">No cobre nuevamente: podría producirse un cobro duplicado.<br/>Verifique esta referencia con casa central.</div>'
        : '';
    final declineReason = declined && message.isNotEmpty
        ? '<div class="c">${_esc(message)}</div>'
        : '';
    final signature = declined || copy == ReceiptCopy.customer
        ? ''
        : '<div class="firma">Firma: ${'.' * 32}</div>';
    final merchantLegend = !declined && copy == ReceiptCopy.merchant
        ? '<div class="firma">ORIGINAL COMERCIO</div>'
        : '';

    return _document(
      body:
          '''
  <table>
    <tr>
      <td class="l">${_esc(_formatDate(op.date))}</td>
      <td class="c b">${_esc(defaults.issuerName)}<br/><span>${_esc(operationTypeLabel(op.result))}</span></td>
      <td class="r">${_esc(_formatTime(op.date))}</td>
    </tr>
  </table>
  <div class="c b merchant">${_esc(defaults.establishmentName)}</div>
  <div class="c">${_esc(defaults.establishmentAddress)}</div>
  <div class="c">${_esc(defaults.establishmentCuit)}</div>
  <div class="detail">
    ${lines.join('\n    ')}
  </div>
  <div class="c big status">${_esc(_statusLabel(op))}</div>
  $declineReason
  $verificationWarning
  $signature
  $customerLegend
  $merchantLegend
  <br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>
''',
    );
  }

  /// Una consulta de saldo aprobada: un solo ticket, copia cliente.
  ///
  /// El encabezado, el comercio y los márgenes son los de [toHtml]. La línea
  /// de saldo ocupa el lugar del resultado y queda a la izquierda, en negrita.
  static String balanceToHtml({
    required DateTime date,
    required ReceiptDefaults defaults,
    required String cardNumber,
    required String expirationDate,
    required double kilograms,
  }) {
    final lines = <String>[
      _line('Terminal', terminalId),
      _line('Comercio', defaults.establishmentCode),
      _line('Lote', defaults.batchNumber),
      _line('Tarjeta', maskPan(cardNumber)),
      _line('Vencimiento', formatCardExpiry(expirationDate)),
    ];
    return _document(
      body:
          '''
  <table>
    <tr>
      <td class="l">${_esc(_formatDate(date))}</td>
      <td class="c b">${_esc(defaults.issuerName)}<br/><span>CONSULTA SALDO</span></td>
      <td class="r">${_esc(_formatTime(date))}</td>
    </tr>
  </table>
  <div class="c b merchant">${_esc(defaults.establishmentName)}</div>
  <div class="c">${_esc(defaults.establishmentAddress)}</div>
  <div class="c">${_esc(defaults.establishmentCuit)}</div>
  <div class="detail">
    ${lines.join('\n    ')}
  </div>
  <div class="b status">${_esc(balanceAmountLine(kilograms))}</div>
  <div class="c b">COPIA CLIENTE</div>
  <br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>
''',
    );
  }

  /// Texto de la consulta de saldo, para pruebas y registro.
  static String balanceToPlainText({
    required DateTime date,
    required ReceiptDefaults defaults,
    required String cardNumber,
    required String expirationDate,
    required double kilograms,
  }) {
    return [
      '${_formatDate(date)}  ${defaults.issuerName}  ${_formatTime(date)}',
      'CONSULTA SALDO',
      defaults.establishmentName,
      defaults.establishmentAddress,
      defaults.establishmentCuit,
      'Terminal: $terminalId',
      'Comercio: ${defaults.establishmentCode}',
      'Lote: ${defaults.batchNumber}',
      'Tarjeta: ${maskPan(cardNumber)}',
      'Vencimiento: ${formatCardExpiry(expirationDate)}',
      balanceAmountLine(kilograms),
      'COPIA CLIENTE',
    ].join('\n');
  }

  /// `SALDO:` más diecisiete puntos, como en el comprobante aprobado.
  static String balanceAmountLine(double kilograms) {
    return 'SALDO:${'.' * 17} KG ${kilograms.toStringAsFixed(2)}';
  }

  /// El vencimiento de la tarjeta llega como `YYMM`. En el papel se lee `MM/YY`.
  static String formatCardExpiry(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      return '${trimmed.substring(2)}/${trimmed.substring(0, 2)}';
    }
    return trimmed;
  }

  static String _document({required String body}) {
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
  .merchant { margin-top: 22px; }
  .detail { text-align: left; padding-top: 28px; }
  .status { margin-top: 32px; margin-bottom: 44px; }
  .firma { text-align: left; white-space: nowrap; }
  hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
</style>
</head>
<body>
$body</body>
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
