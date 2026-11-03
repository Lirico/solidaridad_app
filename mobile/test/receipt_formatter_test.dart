import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_formatter.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

ReceiptDefaults _defaults() {
  return const ReceiptDefaults(
    issuerName: 'Solidaridad',
    establishmentName: 'GAS Terminal — Solidaridad',
    establishmentAddress: 'Av. San Martín 100, Ushuaia',
    establishmentCuit: '30-00000000-0',
    establishmentCode: '00000001',
    couponNumber: '00000001',
    batchNumber: '000001',
    authorizationCode: 'MOCK01',
    currency: 'ARS',
    installments: '1',
    installmentPlan: 'Contado',
    originalChargeNumber: '00000000',
  );
}

OperationModel _operation({
  PaymentResult result = PaymentResult.underReview,
  String card = '6063007014007403',
  String? userMessage = 'Verifique con casa central.',
}) {
  return OperationModel(
    id: 'OP-REF-123',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
    cardNumber: card,
    result: result,
    date: DateTime(2026, 10, 14, 15, 30, 5),
    userMessage: userMessage,
  );
}

void main() {
  test(
    'el comprobante de verificación contiene trazabilidad y advertencia',
    () {
      final defaults = _defaults();
      final text = ReceiptFormatter.toPlainText(_operation(), defaults);

      expect(text, contains('COMPROBANTE DE VERIFICACIÓN'));
      expect(text, contains('Op: OP-REF-123'));
      expect(text, contains('Fecha: 14/10/2026'));
      expect(text, contains('Hora: 15:30:05'));
      expect(text, contains('Comercio: ${defaults.establishmentName}'));
      expect(text, contains('Tipo: Compra'));
      expect(text, contains('Terminal: ${ReceiptFormatter.terminalId}'));
      expect(text, contains('Importe:'));
      expect(text, contains('6063007*****7403'));
      expect(text, contains('No cobre nuevamente'));
      expect(text, contains('Gracias'));
    },
  );

  test('el texto y el HTML incluyen los datos del perfil mock', () {
    final defaults = _defaults();
    final text = ReceiptFormatter.toPlainText(_operation(), defaults);
    final html = ReceiptFormatter.toHtml(_operation(), defaults);

    for (final value in [
      defaults.issuerName,
      defaults.establishmentAddress,
      defaults.establishmentCuit,
      defaults.establishmentCode,
      defaults.couponNumber,
      defaults.batchNumber,
      defaults.authorizationCode,
      defaults.currency,
      defaults.installments,
      defaults.installmentPlan,
      'Verifique con casa central.',
    ]) {
      expect(text, contains(value));
      expect(html, contains(value));
    }
  });

  test('el cargo original solo aparece en una anulación', () {
    final sale = ReceiptFormatter.toPlainText(
      _operation(result: PaymentResult.approved, userMessage: null),
      _defaults(),
    );
    final voided = ReceiptFormatter.toPlainText(
      _operation(result: PaymentResult.voided, userMessage: null),
      _defaults(),
    );

    expect(sale, contains('Tipo: Compra'));
    expect(sale, isNot(contains('Cargo original')));
    expect(voided, contains('Tipo: Anulación'));
    expect(voided, contains('Cargo original: 00000000'));
  });

  test('el HTML de verificación nunca contiene el PAN completo', () {
    const pan = '6063007014007403';
    final html = ReceiptFormatter.toHtml(_operation(card: pan), _defaults());

    expect(html, contains('COMPROBANTE DE VERIFICACIÓN'));
    expect(html, contains('No cobre nuevamente'));
    expect(html, contains('6063007*****7403'));
    expect(html, isNot(contains(pan)));
  });

  test('un PAN que ya viene recortado conserva los últimos 4', () {
    expect(ReceiptFormatter.maskPan('•••• 7403'), '•••• 7403');
    expect(ReceiptFormatter.maskPan('6063007*****7403'), '6063007*****7403');
  });
}
