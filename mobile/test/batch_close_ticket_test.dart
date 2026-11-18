import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/batch_close/domain/batch_close_model.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_formatter.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

const _products = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa backend',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
  ProductInfo(
    code: 'GRANEL',
    label: 'Granel backend',
    unit: ProductUnit(singular: 'm3', plural: 'm3'),
  ),
];

OperationModel _operation({
  required String product,
  required double amount,
  required PaymentResult result,
}) {
  return OperationModel(
    id: 'OP-$product-$amount',
    productCode: product,
    productLabel: 'Etiqueta local ignorada',
    amount: amount,
    cardNumber: '6063007014007403',
    result: result,
    date: DateTime(2026, 11, 12, 18),
  );
}

BatchCloseTicket _ticket(List<OperationModel> operations) {
  return BatchCloseTicket.fromOperations(
    operations: operations,
    products: _products,
  );
}

void main() {
  test(
    'el cierre conserva ventas y anulaciones en la unidad de cada producto',
    () {
      final ticket = _ticket([
        _operation(
          product: 'GRANEL',
          amount: 10.5,
          result: PaymentResult.approved,
        ),
        _operation(
          product: 'GARRAFA_10',
          amount: 1,
          result: PaymentResult.approved,
        ),
        _operation(
          product: 'GARRAFA_10',
          amount: 1,
          result: PaymentResult.approved,
        ),
        _operation(
          product: 'GARRAFA_10',
          amount: 1,
          result: PaymentResult.voided,
        ),
        _operation(
          product: 'GARRAFA_10',
          amount: 4,
          result: PaymentResult.declined,
        ),
      ]);

      expect(ticket.products, hasLength(2));
      final garrafa = ticket.products.first;
      expect(garrafa.code, 'GARRAFA_10');
      expect(garrafa.label, 'Garrafa backend');
      expect(garrafa.salesCount, 3);
      expect(garrafa.salesQuantity, 3);
      expect(garrafa.voidCount, 1);
      expect(garrafa.voidQuantity, 1);
      expect(garrafa.totalCount, 2);
      expect(garrafa.totalQuantity, 2);
      expect(garrafa.unitLabel(garrafa.totalQuantity), 'unidades');

      final granel = ticket.products.last;
      expect(granel.code, 'GRANEL');
      expect(granel.salesQuantity, 10.5);
      expect(granel.unitLabel(granel.salesQuantity), 'm3');
      expect(ticket.salesCount, 4);
      expect(ticket.voidCount, 1);
      expect(ticket.totalCount, 3);
    },
  );

  test('una venta anulada cuenta como venta bruta y deja neto cero', () {
    final ticket = _ticket([
      _operation(
        product: 'GARRAFA_10',
        amount: 2,
        result: PaymentResult.voided,
      ),
    ]);

    expect(ticket.products, hasLength(1));
    expect(ticket.salesCount, 1);
    expect(ticket.products.single.salesQuantity, 2);
    expect(ticket.voidCount, 1);
    expect(ticket.products.single.voidQuantity, 2);
    expect(ticket.totalCount, 0);
    expect(ticket.products.single.totalQuantity, 0);
  });

  test('rechaza códigos ausentes del catálogo backend', () {
    expect(
      () => _ticket([
        _operation(
          product: 'DESCONOCIDO',
          amount: 1,
          result: PaymentResult.approved,
        ),
      ]),
      throwsStateError,
    );
  });

  test('el html usa unidades por producto y sólo conteos globales', () {
    const defaults = ReceiptDefaults(
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
    final html = ReceiptFormatter.batchCloseToHtml(
      date: DateTime(2026, 11, 12, 18),
      defaults: defaults,
      batchNumber: '41',
      ticket: _ticket([
        _operation(
          product: 'GRANEL',
          amount: 10.5,
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
    expect(html, contains('class="band">GRANEL BACKEND'));
    expect(html, contains('VENTAS 001 - 10,5 m3'));
    expect(html, contains('N. CREDITO 000 - 0 m3'));
    expect(html, contains('ANULACIONES 000 - 0 m3'));
    expect(html, contains('TOTALES POR EMISOR'));
    expect(html, contains('VENTAS 001'));
    expect(html, contains('padding-bottom: 28px'));
    expect(html, contains('Cierre de lote OK'));
    expect(html, isNot(contains(' kg')));
    expect(html, isNot(contains(r'$')));
  });
}
