import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/balance/domain/balance_kilograms.dart';
import 'package:solidaridad_app/features/balance/domain/balance_model.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_formatter.dart';

void main() {
  test('el ticket de saldo usa el armado del comprobante de venta', () {
    final defaults = _defaults();
    final date = DateTime(2026, 11, 12, 17, 27, 4);
    final text = ReceiptFormatter.balanceToPlainText(
      date: date,
      defaults: defaults,
      cardNumber: '6063007014007403',
      expirationDate: '2808',
      kilograms: 101,
    );
    final html = ReceiptFormatter.balanceToHtml(
      date: date,
      defaults: defaults,
      cardNumber: '6063007014007403',
      expirationDate: '2808',
      kilograms: 101,
    );

    expect(text, contains('12/11/2026  Solidaridad  17:27:04'));
    expect(text, contains('CONSULTA SALDO'));
    expect(text, isNot(contains('Venta')));
    expect(text, contains(defaults.establishmentName));
    expect(text, contains(defaults.establishmentAddress));
    expect(text, contains(defaults.establishmentCuit));
    expect(text, contains('Terminal: ${ReceiptFormatter.terminalId}'));
    expect(text, contains('Comercio: ${defaults.establishmentCode}'));
    expect(text, contains('Lote: ${defaults.batchNumber}'));
    expect(text, contains('Tarjeta: 6063007*****7403'));
    expect(text, contains('Vencimiento: 08/28'));
    expect(text, contains('SALDO:${'.' * 17} KG 101.00'));
    expect(text, endsWith('COPIA CLIENTE'));
    expect(text, isNot(contains('Cupón')));
    expect(text, isNot(contains('Autorización')));
    expect(text, isNot(contains('Firma')));

    expect(html, contains('class="l">12/11/2026'));
    expect(html, contains('class="r">17:27:04'));
    expect(
      html,
      contains('class="c b">Solidaridad<br/><span>CONSULTA SALDO</span>'),
    );
    expect(
      html,
      contains('class="c b merchant">${defaults.establishmentName}'),
    );
    expect(html, contains('class="c">${defaults.establishmentAddress}'));
    expect(html, contains('class="c">${defaults.establishmentCuit}'));
    expect(html, contains('class="detail"'));
    expect(html, contains('padding-top: 28px'));
    expect(html, contains('margin-top: 22px'));
    expect(html, contains('class="b status">SALDO:${'.' * 17} KG 101.00'));
    expect(html, contains('margin-top: 32px; margin-bottom: 44px'));
    expect(html, contains('class="c b">COPIA CLIENTE'));
    expect(html, isNot(contains('class="c big status"')));
    expect(html, isNot(contains('Firma:')));
  });

  test('el saldo en kg usa la equivalencia del cierre de lote', () {
    final total = balanceKilograms(const [
      BalanceItem(product: 'GARRAFA_10', label: '10 kg', availableBalance: 10),
      BalanceItem(product: 'GARRAFA_15', label: '15 kg', availableBalance: 0.1),
      BalanceItem(product: 'DESCONOCIDO', label: 'otro', availableBalance: 50),
    ]);

    expect(total, closeTo(101.5, 0.001));
  });
}

ReceiptDefaults _defaults() {
  return const ReceiptDefaults(
    issuerName: 'Solidaridad',
    establishmentName: 'Distribuidora Ejemplo',
    establishmentAddress: 'Av. San Martín 1200, Río Grande',
    establishmentCuit: '30-71234567-8',
    establishmentCode: '012502',
    couponNumber: '00000001',
    batchNumber: '000123',
    authorizationCode: 'MOCK01',
    currency: 'ARS',
    installments: '1',
    installmentPlan: 'Contado',
    originalChargeNumber: '00000000',
  );
}
