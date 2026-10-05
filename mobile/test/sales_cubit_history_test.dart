import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_state.dart';

class MockSalesRepository extends Mock implements SalesRepository {}

void main() {
  late MockSalesRepository repository;
  late SalesCubit cubit;

  setUp(() {
    repository = MockSalesRepository();
    cubit = SalesCubit(salesRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('loadHistory emite el fallo en vez de un historial vacío', () async {
    when(
      () => repository.fetchHistory(
        token: any(named: 'token'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(
      const DataLoadException(
        'No se pudo conectar con el servidor. Verifique su red.',
      ),
    );

    final future = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<SalesLoading>(),
        isA<SalesHistoryLoadFailed>().having(
          (state) => state.message,
          'message',
          contains('Verifique su red'),
        ),
      ]),
    );

    await cubit.loadHistory(token: 'token');
    await future;
  });

  test(
    'loadHistory conserva la lista vacía cuando el servidor responde sin ventas',
    () async {
      when(
        () => repository.fetchHistory(
          token: any(named: 'token'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => <OperationModel>[]);

      await cubit.loadHistory(token: 'token');

      expect(cubit.state, isA<SalesInitialWithHistory>());
      expect(cubit.state.history, isEmpty);
    },
  );

  test('loadHistory emite sesión expirada ante 401', () async {
    when(
      () => repository.fetchHistory(
        token: any(named: 'token'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const SessionExpiredException());

    await cubit.loadHistory(token: 'token');

    expect(cubit.state, isA<SalesSessionExpired>());
  });
}
