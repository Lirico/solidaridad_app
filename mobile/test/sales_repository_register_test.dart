import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

import 'helpers/mock_http_client.dart';

void main() {
  late MockHttpClient client;
  late SalesRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    client = MockHttpClient();
    repository = SalesRepository(
      httpClient: client,
      baseUrl: 'http://localhost',
    );
  });

  void stubPost(http.Response response) {
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => response);
  }

  Future<SaleResponse> register() {
    return repository.registerSale(
      product: 'GARRAFA_10',
      amount: '4.0',
      cardNumber: '6063007014007403',
      cvv: '878',
      expirationDate: '1228',
      token: 'token',
      idempotencyKey: 'key-1',
    );
  }

  test('un 202 PENDING queda sin confirmar y no como rechazo', () async {
    stubPost(
      jsonMapResponse({
        'status': 'PENDING',
        'transaction_number': 'OP-9',
        'user_message': 'Operación en curso, reintente en unos segundos',
      }, statusCode: 202),
    );

    final result = await register();

    expect(result.isUnknown, isTrue);
    expect(result.isApproved, isFalse);
    expect(result.connectionError, isFalse);
    expect(result.operationNumber, 'OP-9');
  });

  test('un 201 con estado final no queda en curso', () async {
    stubPost(
      jsonMapResponse({
        'status': 'APPROVED',
        'transaction_number': 'OP-1',
        'user_message': 'Aprobado',
      }, statusCode: 201),
    );

    final approved = await register();
    expect(approved.isApproved, isTrue);
    expect(approved.isUnknown, isFalse);

    stubPost(
      jsonMapResponse({
        'status': 'DECLINED',
        'transaction_number': 'OP-2',
        'user_message': 'Fondos insuficientes',
      }, statusCode: 201),
    );

    final declined = await register();
    expect(declined.isApproved, isFalse);
    expect(declined.isUnknown, isFalse);
  });

  test('el historial lee PENDING como cobro sin confirmar', () {
    final operation = OperationModel.fromJson({
      'transaction_number': 'OP-9',
      'product': 'GARRAFA_10',
      'amount': '4.00',
      'card_last4': '7403',
      'status': 'PENDING',
      'created_at': '2026-10-06T12:00:00Z',
    });

    expect(operation.result, PaymentResult.unknown);
  });
}
