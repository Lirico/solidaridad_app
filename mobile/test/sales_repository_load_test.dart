import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';

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

  void stubGet(Future<http.Response> Function() answer) {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) => answer());
  }

  void stubGetError(Object error) {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenThrow(error);
  }

  group('fetchProducts', () {
    test('lee la unidad que informa el catálogo', () async {
      stubGet(
        () async => jsonListResponse([
          {
            'code': 'GARRAFA_10',
            'label': 'Garrafa 10 kg',
            'unit': {'singular': 'unidad', 'plural': 'unidades'},
          },
          {
            'code': 'GRANEL',
            'label': 'Granel',
            'unit': {'singular': 'm3', 'plural': 'm3'},
          },
        ]),
      );

      final products = await repository.fetchProducts(token: 'token');

      expect(products, hasLength(2));
      expect(products.first.unit.plural, 'unidades');
      expect(products.last.unit.singular, 'm3');
      expect(products.last.unit.plural, 'm3');
    });

    test('lanza DataLoadException ante HTTP 500', () {
      stubGet(() async => http.Response('error', 500));

      expect(
        () => repository.fetchProducts(token: 'token'),
        throwsA(
          isA<DataLoadException>().having(
            (error) => error.message,
            'message',
            'No se pudieron cargar los datos. Reintente.',
          ),
        ),
      );
    });

    test('lanza DataLoadException si no hay red', () {
      stubGetError(const SocketException('failed'));

      expect(
        () => repository.fetchProducts(token: 'token'),
        throwsA(
          isA<DataLoadException>().having(
            (error) => error.message,
            'message',
            contains('Verifique su red'),
          ),
        ),
      );
    });

    test('lanza DataLoadException si el cliente HTTP no conecta', () {
      stubGetError(http.ClientException('failed'));

      expect(
        () => repository.fetchProducts(token: 'token'),
        throwsA(
          isA<DataLoadException>().having(
            (error) => error.message,
            'message',
            contains('Verifique su red'),
          ),
        ),
      );
    });

    test('lanza DataLoadException si se agota el tiempo', () {
      stubGetError(TimeoutException('slow'));

      expect(
        () => repository.fetchProducts(token: 'token'),
        throwsA(
          isA<DataLoadException>().having(
            (error) => error.message,
            'message',
            contains('Tiempo de espera agotado'),
          ),
        ),
      );
    });

    test('sigue lanzando SessionExpiredException ante 401', () {
      stubGet(() async => http.Response('{}', 401));

      expect(
        () => repository.fetchProducts(token: 'token'),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  group('fetchHistory', () {
    test(
      'devuelve la lista vacía cuando la respuesta es 200 sin ítems',
      () async {
        stubGet(() async => jsonMapResponse({'items': []}));

        final items = await repository.fetchHistory(token: 'token');

        expect(items, isEmpty);
      },
    );

    test('lanza DataLoadException ante HTTP 500', () {
      stubGet(() async => http.Response('error', 500));

      expect(
        () => repository.fetchHistory(token: 'token'),
        throwsA(isA<DataLoadException>()),
      );
    });

    test('lanza DataLoadException si no hay red', () {
      stubGetError(const SocketException('failed'));

      expect(
        () => repository.fetchHistory(token: 'token'),
        throwsA(isA<DataLoadException>()),
      );
    });

    test('lanza DataLoadException si se agota el tiempo', () {
      stubGetError(TimeoutException('slow'));

      expect(
        () => repository.fetchHistory(token: 'token'),
        throwsA(isA<DataLoadException>()),
      );
    });

    test('sigue lanzando SessionExpiredException ante 401', () {
      stubGet(() async => http.Response('{}', 401));

      expect(
        () => repository.fetchHistory(token: 'token'),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });
}
