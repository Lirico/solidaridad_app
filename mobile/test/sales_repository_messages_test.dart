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
    registerFallbackValue(Uri.parse('http://localhost/transactions'));
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
      amount: '1.00',
      cardNumber: '6063007014007403',
      cvv: '878',
      expirationDate: '1228',
      token: 'token',
      idempotencyKey: 'key-1',
    );
  }

  test('un 400 de venta muestra message cuando no hay user_message', () async {
    stubPost(
      jsonMapResponse({'message': 'Monto inválido'}, statusCode: 400),
    );

    final result = await register();

    expect(result.isApproved, isFalse);
    expect(result.message, 'Monto inválido');
  });

  test('user_message de la venta tiene prioridad sobre message', () async {
    stubPost(
      jsonMapResponse({
        'message': 'detalle interno',
        'user_message': 'La tarjeta no coincide',
      }, statusCode: 409),
    );

    final result = await register();

    expect(result.message, 'La tarjeta no coincide');
  });

  test('sin texto del servidor la venta usa el fallback', () async {
    stubPost(jsonMapResponse({}, statusCode: 500));

    final result = await register();

    expect(result.message, 'Venta rechazada por la entidad emisora.');
  });

  test('un 201 UNKNOWN no se trata como rechazo ni como error de red', () async {
    stubPost(
      jsonMapResponse({
        'status': 'UNKNOWN',
        'transaction_number': 'OP-9',
        'user_message':
            'No pudimos confirmar el pago. No vuelva a intentarlo; consulte la operación.',
      }, statusCode: 201),
    );

    final result = await register();

    expect(result.isApproved, isFalse);
    expect(result.isUnknown, isTrue);
    expect(result.connectionError, isFalse);
    expect(result.message, contains('No vuelva a intentarlo'));
  });

  test('un 400 de anulación muestra message', () async {
    stubPost(
      jsonMapResponse(
        {'message': 'Solo se pueden anular transacciones aprobadas'},
        statusCode: 400,
      ),
    );

    final result = await repository.voidTransaction(
      token: 'token',
      transactionNumber: 'OP-1',
      cardNumber: '6063007014007403',
    );

    expect(result.isDeclined, isTrue);
    expect(result.message, 'Solo se pueden anular transacciones aprobadas');
  });
}
