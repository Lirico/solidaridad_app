import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_formatter.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

OperationModel _underReviewOperation({String card = '6063007014007403'}) {
  return OperationModel(
    id: 'OP-REF-123',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
    cardNumber: card,
    result: PaymentResult.underReview,
    date: DateTime(2026, 10, 14, 15, 30, 5),
    userMessage: 'Verifique con casa central.',
  );
}

void main() {
  test(
    'el comprobante de verificación contiene trazabilidad y advertencia',
    () {
      final text = ReceiptFormatter.toPlainText(_underReviewOperation());

      expect(text, contains('COMPROBANTE DE VERIFICACIÓN'));
      expect(text, contains('Op:     OP-REF-123'));
      expect(text, contains('Fecha:  14/10/2026'));
      expect(text, contains('Hora:   15:30:05'));
      expect(text, contains('Comercio: ${ReceiptFormatter.merchantName}'));
      expect(text, contains('Terminal: ${ReceiptFormatter.terminalId}'));
      expect(text, contains('Monto:'));
      expect(text, contains('•••• 7403'));
      expect(text, contains('No cobre nuevamente'));
    },
  );

  test('el HTML de verificación nunca contiene el PAN completo', () {
    final html = ReceiptFormatter.toHtml(_underReviewOperation());

    expect(html, contains('COMPROBANTE DE VERIFICACIÓN'));
    expect(html, contains('No cobre nuevamente'));
    expect(html, contains('•••• 7403'));
    expect(html, isNot(contains('6063007014007403')));
  });
}
