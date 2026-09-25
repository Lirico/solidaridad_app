import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

import 'helpers/mock_http_client.dart';

void main() {
  late MockHttpClient client;
  late SalesRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    client = MockHttpClient();
    repository = SalesRepository(
      httpClient: client,
      baseUrl: 'http://localhost/v1',
    );
  });

  test('el 400 de anulación muestra el message de la API', () async {
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => jsonMapResponse({
        'message':
            'No pudimos confirmar el cobro. No se puede anular hasta saber si el pago se acreditó.',
      }, statusCode: 400),
    );

    final result = await repository.voidTransaction(
      token: 'token',
      transactionNumber: 'OP-1',
      cardNumber: '4111111111111111',
    );

    expect(result.isDeclined, isTrue);
    expect(
      result.message,
      'No pudimos confirmar el cobro. No se puede anular hasta saber si el pago se acreditó.',
    );
  });

  test('fetchTransaction lee estado y can_void', () async {
    when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonMapResponse({
        'transaction_number': 'OP-1',
        'product': 'GARRAFA_10',
        'amount': '1.50',
        'card_last4': '1111',
        'status': 'UNKNOWN',
        'user_message': 'No pudimos confirmar la anulación.',
        'can_void': true,
        'created_at': '2026-09-25T12:00:00Z',
      }),
    );

    final operation = await repository.fetchTransaction(
      token: 'token',
      transactionNumber: 'OP-1',
    );

    expect(operation.result, PaymentResult.unknown);
    expect(operation.canVoid, isTrue);
    expect(operation.id, 'OP-1');
  });
}
