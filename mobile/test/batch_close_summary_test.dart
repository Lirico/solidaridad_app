import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/features/batch_close/domain/batch_close_model.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

/// Fecha "de hoy" usada como referencia en todos los casos.
final DateTime _now = DateTime(2026, 9, 22, 15, 30);
final DateTime _todayMorning = DateTime(2026, 9, 22, 9, 0);
final DateTime _todayAfternoon = DateTime(2026, 9, 22, 14, 0);
final DateTime _yesterday = DateTime(2026, 9, 21, 23, 59);

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
    test('agrupa las ventas aprobadas y calcula kg por producto', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000123',
        now: _now,
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
      expect(garrafa.kg, closeTo(150, 0.001));
      expect(garrafa.unitLabel, 'unidades');

      final BatchProductItem granel = summary.products.last;
      expect(granel.productCode, 'GRANEL');
      expect(granel.kg, closeTo(1200, 0.001));
      expect(granel.unitLabel, 'm³');

      expect(summary.totalKg, closeTo(1665, 0.001));
    });

    test('acumula varias ventas del mismo producto', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        now: _now,
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
      expect(summary.products.single.kg, closeTo(82.5, 0.001));
    });

    test('ignora ventas rechazadas, anuladas y con error de conexión', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        now: _now,
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
      expect(summary.totalKg, 0);
    });

    test('ignora las ventas de días anteriores', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        now: _now,
        operations: [
          _operation(productCode: 'GARRAFA_10', amount: 5, date: _yesterday),
          _operation(productCode: 'GARRAFA_10', amount: 2, date: _todayMorning),
        ],
      );

      expect(summary.salesCount, 1);
      expect(summary.products.single.quantity, 2);
    });

    test('ordena los productos según el catálogo', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        now: _now,
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

    test('un producto fuera del catálogo usa kg 1:1 y queda al final', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000001',
        now: _now,
        operations: [
          _operation(productCode: 'OTRO', amount: 3, date: _todayMorning),
          _operation(productCode: 'GARRAFA_10', amount: 1, date: _todayMorning),
        ],
      );

      expect(summary.products.last.productCode, 'OTRO');
      expect(summary.products.last.kg, closeTo(3, 0.001));
      expect(summary.products.last.unitLabel, 'unidades');
    });

    test('conserva el número de lote y la marca de resumen parcial', () {
      final BatchSummary summary = BatchSummary.fromOperations(
        batchNumber: '000007',
        now: _now,
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
