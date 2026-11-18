import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/features/batch_close/domain/batch_close_model.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

final DateTime _todayMorning = DateTime(2026, 9, 22, 9, 0);
final DateTime _todayAfternoon = DateTime(2026, 9, 22, 14, 0);
final DateTime _yesterday = DateTime(2026, 9, 21, 23, 59);

const List<ProductInfo> _products = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa 10 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
  ProductInfo(
    code: 'GARRAFA_15',
    label: 'Garrafa 15 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
  ProductInfo(
    code: 'GARRAFA_30',
    label: 'Garrafa 30 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
  ProductInfo(
    code: 'TUBO_45',
    label: 'Tubo 45 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
  ProductInfo(
    code: 'GRANEL',
    label: 'Granel',
    unit: ProductUnit(singular: 'm3', plural: 'm3'),
  ),
];

OperationModel _operation({
  required String productCode,
  required double amount,
  required DateTime date,
  PaymentResult result = PaymentResult.approved,
  String? productLabel,
}) {
  return OperationModel(
    id: 'OP-260922-00000001',
    productCode: productCode,
    productLabel: productLabel ?? productCode,
    amount: amount,
    cardNumber: '•••• 1111',
    result: result,
    date: date,
  );
}

void main() {
  group('BatchSummary.fromOperations', () {
    test('agrupa ventas y usa etiqueta, orden y unidad de /products', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000123',
        products: _products,
        operations: [
          _operation(
            productCode: 'GARRAFA_10',
            productLabel: 'Garrafa 10 kg',
            amount: 15,
            date: _todayMorning,
          ),
          _operation(
            productCode: 'TUBO_45',
            productLabel: 'Tubo 45 kg',
            amount: 7,
            date: _todayAfternoon,
          ),
          _operation(
            productCode: 'GRANEL',
            productLabel: 'Granel',
            amount: 1200,
            date: _todayMorning,
          ),
        ],
      );

      expect(summary.batchNumber, '000123');
      expect(summary.salesCount, 3);
      expect(summary.isPartial, isFalse);
      expect(summary.products.length, 3);

      final BatchProductItem garrafa = summary.products.first;
      expect(garrafa.productCode, 'GARRAFA_10');
      expect(garrafa.label, 'Garrafa 10 kg');
      expect(garrafa.quantity, 15);
      expect(garrafa.unitLabel, 'unidades');

      final BatchProductItem granel = summary.products.last;
      expect(granel.productCode, 'GRANEL');
      expect(granel.quantity, closeTo(1200, 0.001));
      expect(granel.unitLabel, 'm3');
    });

    test('acumula varias ventas del mismo producto', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        products: _products,
        operations: [
          _operation(productCode: 'GARRAFA_15', amount: 3, date: _todayMorning),
          _operation(
            productCode: 'GARRAFA_15',
            amount: 2.5,
            date: _todayAfternoon,
          ),
        ],
      );

      expect(summary.salesCount, 2);
      expect(summary.products.length, 1);
      expect(summary.products.single.quantity, closeTo(5.5, 0.001));
      expect(summary.products.single.unitLabel, 'unidades');
    });

    test('ignora ventas rechazadas, anuladas y con error de conexión', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        products: _products,
        operations: [
          _operation(
            productCode: 'GARRAFA_10',
            amount: 10,
            date: _todayMorning,
            result: PaymentResult.declined,
          ),
          _operation(
            productCode: 'GARRAFA_10',
            amount: 10,
            date: _todayMorning,
            result: PaymentResult.voided,
          ),
          _operation(
            productCode: 'GARRAFA_10',
            amount: 10,
            date: _todayMorning,
            result: PaymentResult.connectionError,
          ),
        ],
      );

      expect(summary.salesCount, 0);
      expect(summary.products, isEmpty);
    });

    test('incluye ventas de cualquier fecha del lote actual', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        products: _products,
        operations: [
          _operation(productCode: 'GARRAFA_10', amount: 5, date: _yesterday),
          _operation(productCode: 'GARRAFA_10', amount: 2, date: _todayMorning),
        ],
      );

      expect(summary.salesCount, 2);
      expect(summary.products.single.quantity, 7);
    });

    test('ordena los productos según el catálogo', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        products: _products,
        operations: [
          _operation(productCode: 'GRANEL', amount: 1, date: _todayMorning),
          _operation(productCode: 'TUBO_45', amount: 1, date: _todayMorning),
          _operation(productCode: 'GARRAFA_10', amount: 1, date: _todayMorning),
          _operation(productCode: 'GARRAFA_30', amount: 1, date: _todayMorning),
          _operation(productCode: 'GARRAFA_15', amount: 1, date: _todayMorning),
        ],
      );

      expect(summary.products.map((item) => item.productCode).toList(), [
        'GARRAFA_10',
        'GARRAFA_15',
        'GARRAFA_30',
        'TUBO_45',
        'GRANEL',
      ]);
    });

    test('rechaza un producto ausente de /products', () {
      expect(
        () => BatchSummary.fromOperations(
          batchNumber: '000001',
          products: _products,
          operations: [
            _operation(productCode: 'OTRO', amount: 3, date: _todayMorning),
          ],
        ),
        throwsStateError,
      );
    });

    test('conserva el número de lote y la marca de resumen parcial', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000007',
        products: _products,
        isPartial: true,
        operations: [
          _operation(productCode: 'GARRAFA_10', amount: 1, date: _todayMorning),
        ],
      );

      expect(summary.batchNumber, '000007');
      expect(summary.isPartial, isTrue);
    });
  });
}
