import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

void main() {
  test('UNKNOWN con can_void se puede volver a anular', () {
    final operation = OperationModel.fromJson({
      'transaction_number': 'OP-1',
      'product': 'GARRAFA_10',
      'amount': '1.50',
      'card_last4': '1111',
      'status': 'UNKNOWN',
      'user_message': 'No pudimos confirmar la anulación.',
      'can_void': true,
      'created_at': '2026-09-25T12:00:00Z',
    });

    expect(operation.result, PaymentResult.unknown);
    expect(operation.canVoid, isTrue);
    expect(operation.userMessage, 'No pudimos confirmar la anulación.');
  });

  test('UNKNOWN de un cobro sin confirmar no se puede anular', () {
    final operation = OperationModel.fromJson({
      'transaction_number': 'OP-2',
      'product': 'GARRAFA_10',
      'amount': '1.50',
      'card_last4': '1111',
      'status': 'UNKNOWN',
      'user_message': 'No pudimos confirmar el pago.',
      'can_void': false,
      'created_at': '2026-09-25T12:00:00Z',
    });

    expect(operation.result, PaymentResult.unknown);
    expect(operation.canVoid, isFalse);
  });
}
