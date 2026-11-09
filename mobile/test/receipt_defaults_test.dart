import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';

void main() {
  test('fromJson lee cada campo del perfil del comprobante', () {
    final defaults = ReceiptDefaults.fromJson(const {
      'issuer_name': 'Solidaridad',
      'establishment_name': 'GAS Terminal — Solidaridad',
      'establishment_address': 'Av. San Martín 100, Ushuaia',
      'establishment_cuit': '30-00000000-0',
      'establishment_code': '00000001',
      'coupon_number': '00000001',
      'batch_number': '000001',
      'authorization_code': 'MOCK01',
      'currency': 'ARS',
      'installments': '1',
      'installment_plan': 'Contado',
      'original_charge_number': '00000000',
    });

    expect(defaults.issuerName, 'Solidaridad');
    expect(defaults.establishmentName, 'GAS Terminal — Solidaridad');
    expect(defaults.establishmentAddress, 'Av. San Martín 100, Ushuaia');
    expect(defaults.establishmentCuit, '30-00000000-0');
    expect(defaults.establishmentCode, '00000001');
    expect(defaults.couponNumber, '00000001');
    expect(defaults.batchNumber, '000001');
    expect(defaults.authorizationCode, 'MOCK01');
    expect(defaults.currency, 'ARS');
    expect(defaults.installments, '1');
    expect(defaults.installmentPlan, 'Contado');
    expect(defaults.originalChargeNumber, '00000000');
  });

  test('fromJson rechaza un campo vacío', () {
    expect(
      () => ReceiptDefaults.fromJson(const {
        'issuer_name': ' ',
        'establishment_name': 'Comercio',
        'establishment_address': 'Domicilio',
        'establishment_cuit': '30-00000000-0',
        'establishment_code': '00000001',
        'coupon_number': '00000001',
        'batch_number': '000001',
        'authorization_code': 'MOCK01',
        'currency': 'ARS',
        'installments': '1',
        'installment_plan': 'Contado',
        'original_charge_number': '00000000',
      }),
      throwsFormatException,
    );
  });
}
