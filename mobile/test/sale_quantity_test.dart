import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

void main() {
  test('garrafa rechaza decimales y un tercer dígito', () {
    expect(
      validateSaleQuantity('3,5', allowsDecimals: false),
      'La cantidad debe ser un número entero',
    );
    expect(
      validateSaleQuantity('1,005', allowsDecimals: false),
      'La cantidad admite como máximo 2 decimales',
    );
    expect(validateSaleQuantity('2', allowsDecimals: false), isNull);
  });

  test('granel acepta hasta 2 decimales', () {
    expect(validateSaleQuantity('2,5', allowsDecimals: true), isNull);
    expect(
      validateSaleQuantity('1,005', allowsDecimals: true),
      'La cantidad admite como máximo 2 decimales',
    );
  });

  test('fromJson usa la unidad del catálogo', () {
    final bulk = ProductInfo.fromJson({
      'code': 'GRANEL',
      'label': 'Granel',
      'unit': {'singular': 'm3', 'plural': 'm3'},
    });
    final cylinder = ProductInfo.fromJson({
      'code': 'GARRAFA_10',
      'label': 'Garrafa 10 kg',
      'unit': {'singular': 'unidad', 'plural': 'unidades'},
    });

    expect(bulk.unit.allowsDecimals, isTrue);
    expect(cylinder.unit.allowsDecimals, isFalse);
  });
}
