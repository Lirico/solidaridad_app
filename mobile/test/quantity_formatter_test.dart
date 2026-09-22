import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/core/formatters/quantity_formatter.dart';

void main() {
  group('formatQuantityEs', () {
    test('agrupa miles con punto', () {
      expect(formatQuantityEs(1200), '1.200');
      expect(formatQuantityEs(125750), '125.750');
      expect(formatQuantityEs(999), '999');
      expect(formatQuantityEs(0), '0');
    });

    test('respeta los decimales pedidos', () {
      expect(formatQuantityEs(1234.5, decimals: 1), '1.234,5');
      expect(formatQuantityEs(1234.56, decimals: 2), '1.234,56');
      // Sin decimales, redondea.
      expect(formatQuantityEs(1234.5), '1.235');
    });

    test('usa negativo y separador decimal es-AR', () {
      expect(formatQuantityEs(-1234.5, decimals: 1), '-1.234,5');
    });
  });
}
