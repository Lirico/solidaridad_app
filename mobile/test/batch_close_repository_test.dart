import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/batch_close/data/batch_close_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

import 'helpers/mock_http_client.dart';

const String _baseUrl = 'http://test/v1';

final DateTime _now = DateTime(2026, 9, 22, 15, 30);
final DateTime _today = DateTime(2026, 9, 22, 13, 0);
final DateTime _yesterday = DateTime(2026, 9, 21, 23, 0);

Map<String, dynamic> _item({
  String product = 'GARRAFA_10',
  double amount = 1,
  DateTime? date,
  String status = 'APPROVED',
}) {
  return <String, dynamic>{
    'transaction_number': 'OP-260922-00000001',
    'product': product,
    'amount': amount.toString(),
    'card_last4': '1111',
    'status': status,
    'user_message': 'Aprobada',
    'created_at': (date ?? _today).toIso8601String(),
  };
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
}) => <String, dynamic>{'items': items, 'total': total};

/// Stubea `GET /transactions` respondiendo según el `offset` pedido.
void _stubGet(
  MockHttpClient client,
  http.Response Function(int offset) responder,
) {
  when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer((
    invocation,
  ) async {
    final Uri uri = invocation.positionalArguments.first as Uri;
    return responder(int.parse(uri.queryParameters['offset'] ?? '0'));
  });
}

void main() {
  late MockHttpClient client;
  late BatchCloseRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    client = MockHttpClient();
    repository = BatchCloseRepository(httpClient: client, baseUrl: _baseUrl);
  });

  test('devuelve las operaciones y corta con una sola página', () async {
    _stubGet(
      client,
      (_) => jsonMapResponse(
        _page(
          items: [
            _item(amount: 15),
            _item(product: 'TUBO_45', amount: 7),
          ],
          total: 2,
        ),
      ),
    );

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
      now: _now,
    );

    expect(result.sessionExpired, isFalse);
    expect(result.connectionError, isFalse);
    expect(result.isPartial, isFalse);
    expect(result.operations.length, 2);
    expect(result.operations.first.productCode, 'GARRAFA_10');
    expect(result.operations.first.result, PaymentResult.approved);
    expect(result.operations.first.amount, 15);
    verify(
      () => client.get(
        Uri.parse('$_baseUrl/transactions?limit=100&offset=0'),
        headers: any(named: 'headers'),
      ),
    ).called(1);
  });

  test('401 marca la sesión como expirada', () async {
    when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async =>
          jsonResponse('{"message":"Token inválido"}', statusCode: 401),
    );

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
    );

    expect(result.sessionExpired, isTrue);
    expect(result.connectionError, isFalse);
    expect(result.operations, isEmpty);
  });

  test(
    'un error HTTP se informa como error de conexión con el código',
    () async {
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => jsonResponse('{"message":"boom"}', statusCode: 500),
      );

      final BatchCloseLoadResult result = await repository.loadOperations(
        token: 'tok',
      );

      expect(result.connectionError, isTrue);
      expect(result.errorMessage, contains('500'));
      expect(result.operations, isEmpty);
    },
  );

  test('timeout informa error de conexión', () async {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => throw TimeoutException('sin respuesta'));

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
    );

    expect(result.connectionError, isTrue);
    expect(result.errorMessage, 'Tiempo de espera agotado. Reintente.');
  });

  test('sin red informa error de conexión', () async {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => throw const SocketException('sin ruta'));

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
    );

    expect(result.connectionError, isTrue);
    expect(
      result.errorMessage,
      'No se pudo conectar con el servidor. Verifique su red.',
    );
  });

  test('pagina mientras la ventana del lote siga abierta', () async {
    _stubGet(client, (offset) {
      if (offset == 0) {
        return jsonMapResponse(
          _page(
            items: List<Map<String, dynamic>>.generate(100, (_) => _item()),
            total: 250,
          ),
        );
      }
      return jsonMapResponse(
        _page(
          items: List<Map<String, dynamic>>.generate(
            100,
            (index) => _item(date: index == 99 ? _yesterday : _today),
          ),
          total: 250,
        ),
      );
    });

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
      now: _now,
    );

    // La segunda página entra completa, pero su último ítem ya es de ayer:
    // no hace falta pedir la tercera.
    expect(result.operations.length, 200);
    expect(result.isPartial, isFalse);
    verify(() => client.get(any(), headers: any(named: 'headers'))).called(2);
  });

  test(
    'el corte del último cierre local también limita la paginación',
    () async {
      _stubGet(
        client,
        (_) => jsonMapResponse(
          _page(
            items: List<Map<String, dynamic>>.generate(5, (_) => _item()),
            total: 5,
          ),
        ),
      );

      final BatchCloseLoadResult result = await repository.loadOperations(
        token: 'tok',
        after: DateTime(2026, 9, 22, 14, 0),
        now: _now,
      );

      // Las 5 ventas de las 13:00 quedaron antes del último cierre: se devuelven
      // (el filtrado fino lo hace el dominio) y no se pide otra página.
      expect(result.operations.length, 5);
      verify(() => client.get(any(), headers: any(named: 'headers'))).called(1);
    },
  );

  test('marca el resumen como parcial al agotar el tope de páginas', () async {
    _stubGet(
      client,
      (_) => jsonMapResponse(
        _page(
          items: List<Map<String, dynamic>>.generate(100, (_) => _item()),
          total: 2000,
        ),
      ),
    );

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
      now: _now,
    );

    expect(result.operations.length, 1000);
    expect(result.isPartial, isTrue);
    verify(() => client.get(any(), headers: any(named: 'headers'))).called(10);
  });

  test('una lista vacía no genera más pedidos', () async {
    _stubGet(client, (_) => jsonMapResponse(_page(items: const [], total: 0)));

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: 'tok',
      now: _now,
    );

    expect(result.operations, isEmpty);
    expect(result.isPartial, isFalse);
    verify(() => client.get(any(), headers: any(named: 'headers'))).called(1);
  });
}
