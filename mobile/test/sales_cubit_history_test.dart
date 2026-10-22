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

  test(
    'conserva la venta aprobada y la marca en revisión tras void ambiguo',
    () async {
      const transactionNumber = 'OP-1';
      when(
        () => repository.fetchHistory(
          token: any(named: 'token'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          OperationModel(
            id: transactionNumber,
            productCode: 'GARRAFA_10',
            productLabel: 'Garrafa 10 kg',
            amount: 1,
            cardNumber: '•••• 1111',
            result: PaymentResult.approved,
            date: DateTime(2026, 10, 22),
          ),
        ],
      );
      when(
        () => repository.voidTransaction(
          token: any(named: 'token'),
          transactionNumber: any(named: 'transactionNumber'),
          cardNumber: any(named: 'cardNumber'),
          expirationDate: any(named: 'expirationDate'),
        ),
      ).thenAnswer((_) async => const VoidResult.underReview());

      await cubit.loadHistory(token: 'token');
      final result = await cubit.voidSale(
        token: 'token',
        transactionNumber: transactionNumber,
        cardNumber: '4111111111111111',
      );

      expect(result.isUnderReview, isTrue);
      expect(cubit.state.history.single.result, PaymentResult.underReview);
    },
  );
}
