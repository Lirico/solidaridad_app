import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';

import 'helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://fallback.test'));
  });

  test('el timeout de venta supera el presupuesto de 35 s del backend', () {
    expect(kSaleRequestTimeout, greaterThan(const Duration(seconds: 35)));
  });

  test(
    'si el POST no responde, el cobro queda pendiente y no sugiere reintentar',
    () async {
      final client = MockHttpClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) => Completer<http.Response>().future);

      final repository = SalesRepository(
        httpClient: client,
        baseUrl: 'http://example.test/v1',
        saleTimeout: const Duration(milliseconds: 20),
      );

      final result = await repository.registerSale(
        product: 'GARRAFA_10',
        amount: '1.00',
        cardNumber: '6063007014007403',
        cvv: '123',
        expirationDate: '1228',
        token: 'token',
      );

      expect(result.connectionError, isTrue);
      expect(result.isApproved, isFalse);
      expect(result.message, kSalePendingConfirmationMessage);
      expect(result.message.toLowerCase(), isNot(contains('reintente')));
    },
  );
}
