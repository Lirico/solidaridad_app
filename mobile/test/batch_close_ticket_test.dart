import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/batch_close/domain/batch_close_model.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_formatter.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

OperationModel _operation({
  required String product,
  required String label,
  required double amount,
  required PaymentResult result,
}) {
  return OperationModel(
    id: 'OP-$product-$amount',
    productCode: product,
    productLabel: label,
    amount: amount,
    cardNumber: '6063007014007403',
    result: result,
    date: DateTime(2026, 11, 12, 18),
  );
}

void main() {
  test('el cierre suma ventas y anulaciones en kilos por producto', () {
    final BatchCloseTicket ticket = BatchCloseTicket.fromOperations([
      _operation(
        product: 'GRANEL',
        label: 'Granel',
        amount: 10,
        result: PaymentResult.approved,
      ),
      _operation(
        product: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        amount: 1,
        result: PaymentResult.approved,
      ),
      _operation(
        product: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        amount: 1,
        result: PaymentResult.approved,
      ),
      _operation(
        product: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        amount: 1,
        result: PaymentResult.voided,
      ),
      _operation(
        product: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        amount: 4,
        result: PaymentResult.declined,
      ),
    ]);

    expect(ticket.products, hasLength(2));
    expect(ticket.products.first.code, 'GARRAFA_10');
    expect(ticket.products.first.salesCount, 2);
    expect(ticket.products.first.salesKg, 20);
    expect(ticket.products.first.voidCount, 1);
    expect(ticket.products.first.voidKg, 10);
    expect(ticket.products.first.totalCount, 1);
    expect(ticket.products.first.totalKg, 10);
    expect(ticket.products.last.code, 'GRANEL');
    expect(ticket.salesCount, 3);
    expect(ticket.salesKg, 30);
    expect(ticket.voidCount, 1);
    expect(ticket.voidKg, 10);
    expect(ticket.totalCount, 2);
    expect(ticket.totalKg, 20);
  });

  test('el html del cierre usa la cabecera del ticket y kilos', () {
    const ReceiptDefaults defaults = ReceiptDefaults(
      issuerName: 'Solidaridad',
      establishmentName: 'Distribuidora Ejemplo',
      establishmentAddress: 'Av. San Martín 1200, Río Grande',
      establishmentCuit: '30-71234567-8',
      establishmentCode: '012502',
      couponNumber: '',
      batchNumber: '',
      authorizationCode: '',
      currency: 'ARS',
      installments: '1',
      installmentPlan: 'Contado',
      originalChargeNumber: '',
    );
    final String html = ReceiptFormatter.batchCloseToHtml(
      date: DateTime(2026, 11, 12, 18),
      defaults: defaults,
      batchNumber: '41',
      ticket: BatchCloseTicket.fromOperations([
        _operation(
          product: 'GRANEL',
          label: 'Granel',
          amount: 10,
          result: PaymentResult.approved,
        ),
      ]),
    );

    expect(html, contains('class="l">12/11/2026'));
    expect(html, contains('class="r">18:00:00'));
    expect(html, contains('Solidaridad<br/><span>CIERRE DE LOTE</span>'));
    expect(html, contains('class="c b merchant">Distribuidora Ejemplo'));
    expect(html, contains('Terminal: ${ReceiptFormatter.terminalId}'));
    expect(html, contains('Comercio: 012502'));
    expect(html, contains('Lote: 41'));
    expect(html, contains('class="band">GRANEL'));
    expect(html, contains('VENTAS 001 - 10,00 kg'));
    expect(html, contains('N. CREDITO 000 - 0,00 kg'));
    expect(html, contains('ANULACIONES 000 - 0,00 kg'));
    expect(html, contains('TOTALES POR EMISOR'));
    expect(html, contains('padding-bottom: 28px'));
    expect(html, contains('Cierre de lote OK'));
    expect(html, isNot(contains('VER:')));
    expect(html, isNot(contains('\$')));
  });
}
