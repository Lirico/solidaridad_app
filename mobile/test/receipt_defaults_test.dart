import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

OperationModel _operation({
  String? couponNumber = '00000042',
  String? authorizationCode = 'A99881',
}) {
  return OperationModel(
    id: 'OP-1',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
    cardNumber: '•••• 7403',
    result: PaymentResult.approved,
    date: DateTime(2026, 11, 11),
    couponNumber: couponNumber,
    authorizationCode: authorizationCode,
  );
}

void main() {
  test('forSale usa el comercio de la cuenta y el cupón de la venta', () {
    final defaults = ReceiptDefaults.forSale(
      merchantCode: '014114',
      merchantName: 'COMERCIO REAL',
      merchantAddress: 'Alem 100',
      merchantCity: 'Tolhuin',
      merchantTaxId: '30-71234567-8',
      operation: _operation(),
    );

    expect(defaults.issuerName, 'Solidaridad');
    expect(defaults.establishmentName, 'COMERCIO REAL');
    expect(defaults.establishmentAddress, 'Alem 100, Tolhuin');
    expect(defaults.establishmentCuit, '30-71234567-8');
    expect(defaults.establishmentCode, '014114');
    expect(defaults.couponNumber, '00000042');
    expect(defaults.authorizationCode, 'A99881');
    expect(defaults.currency, 'ARS');
    expect(defaults.installments, '1');
    expect(defaults.installmentPlan, 'Contado');
    expect(defaults.batchNumber, isEmpty);
    expect(defaults.originalChargeNumber, isEmpty);
  });

  test('sin ciudad la dirección queda sola', () {
    final defaults = ReceiptDefaults.forSale(
      merchantCode: '014114',
      merchantName: 'COMERCIO REAL',
      merchantAddress: 'Alem 100',
      merchantCity: '  ',
      merchantTaxId: '30-71234567-8',
      operation: _operation(),
    );

    expect(defaults.establishmentAddress, 'Alem 100');
  });

  test('sin receipt el cupón y la autorización quedan vacíos', () {
    final defaults = ReceiptDefaults.forSale(
      merchantCode: '014114',
      merchantName: 'COMERCIO REAL',
      merchantAddress: 'Alem 100',
      merchantCity: 'Tolhuin',
      merchantTaxId: '30-71234567-8',
      operation: _operation(couponNumber: null, authorizationCode: null),
    );

    expect(defaults.couponNumber, isEmpty);
    expect(defaults.authorizationCode, isEmpty);
  });

  test('fromJson lee receipt y tolera su ausencia', () {
    final approved = OperationModel.fromJson({
      'transaction_number': 'OP-1',
      'product': 'GARRAFA_10',
      'amount': '4.00',
      'card_last4': '7403',
      'status': 'APPROVED',
      'created_at': '2026-11-11T12:00:00Z',
      'receipt': {'coupon_number': '00000042', 'authorization_code': 'A99881'},
    });
    final declined = OperationModel.fromJson({
      'transaction_number': 'OP-2',
      'product': 'GARRAFA_10',
      'amount': '4.00',
      'card_last4': '7403',
      'status': 'DECLINED',
      'created_at': '2026-11-11T12:00:00Z',
      'receipt': null,
    });

    expect(approved.couponNumber, '00000042');
    expect(approved.authorizationCode, 'A99881');
    expect(declined.couponNumber, isNull);
    expect(declined.authorizationCode, isNull);
  });
}
