import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_state.dart';

class MockSalesRepository extends Mock implements SalesRepository {}

const _pending = SaleResponse(
  isApproved: false,
  operationNumber: 'OP-1',
  message: 'Operación en curso',
  errorCode: 'PENDING',
  authorizationStatus: SaleAuthorizationStatus.pending,
  pendingReason: PendingSaleReason.processing,
  pollAfterSeconds: 3,
  mayStartNewSale: false,
);

const _underReview = SaleResponse(
  isApproved: false,
  operationNumber: 'OP-1',
  message: 'Debe verificar la operación.',
  errorCode: 'PENDING',
  authorizationStatus: SaleAuthorizationStatus.pending,
  pendingReason: PendingSaleReason.underReview,
  mayStartNewSale: true,
);

SaleResponse _finalResponse(SaleAuthorizationStatus status) => SaleResponse(
  isApproved: status == SaleAuthorizationStatus.approved,
  operationNumber: 'OP-1',
  message: status.name,
  errorCode: status.name,
  authorizationStatus: status,
);

void main() {
  late MockSalesRepository repository;

  setUp(() {
    repository = MockSalesRepository();
  });

  SalesCubit makeCubit({
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
    Duration timeout = const Duration(minutes: 2),
  }) => SalesCubit(
    salesRepository: repository,
    wait: wait,
    now: now,
    pollingTimeout: timeout,
  );

  void openReview(SalesCubit cubit) {
    cubit.showReview(
      productCode: 'GARRAFA_10',
      productLabel: 'Garrafa 10 kg',
      amount: 4,
      cardNumber: '6063007014007403',
      cvv: '878',
      expirationDate: '1228',
    );
  }

  void stubRegister(SaleResponse response) {
    when(
      () => repository.registerSale(
        product: any(named: 'product'),
        amount: any(named: 'amount'),
        cardNumber: any(named: 'cardNumber'),
        cvv: any(named: 'cvv'),
        expirationDate: any(named: 'expirationDate'),
        token: any(named: 'token'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => response);
  }

  test('PENDING se consulta hasta recibir cada estado final', () async {
    for (final status in [
      SaleAuthorizationStatus.approved,
      SaleAuthorizationStatus.declined,
      SaleAuthorizationStatus.failed,
    ]) {
      final cubit = makeCubit(wait: (_) async {});
      addTearDown(cubit.close);
      openReview(cubit);
      stubRegister(_pending);
      when(
        () =>
            repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
      ).thenAnswer((_) async => _finalResponse(status));

      await cubit.sendIsoMessage(token: 'token');

      expect(cubit.state, isA<SalesCompleted>());
      expect((cubit.state as SalesCompleted).result.name, status.name);
      verify(
        () => repository.registerSale(
          product: any(named: 'product'),
          amount: any(named: 'amount'),
          cardNumber: any(named: 'cardNumber'),
          cvv: any(named: 'cvv'),
          expirationDate: any(named: 'expirationDate'),
          token: any(named: 'token'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    }
  });

  test('usa el intervalo indicado por la API en cada consulta', () async {
    final waits = <Duration>[];
    var polls = 0;
    final cubit = makeCubit(wait: (duration) async => waits.add(duration));
    addTearDown(cubit.close);
    openReview(cubit);
    stubRegister(_pending);
    when(
      () => repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
    ).thenAnswer((_) async {
      polls += 1;
      return polls == 1
          ? const SaleResponse(
              isApproved: false,
              operationNumber: 'OP-1',
              message: 'Sigue en curso',
              errorCode: 'PENDING',
              authorizationStatus: SaleAuthorizationStatus.pending,
              pendingReason: PendingSaleReason.processing,
              pollAfterSeconds: 7,
              mayStartNewSale: false,
            )
          : _finalResponse(SaleAuthorizationStatus.approved);
    });

    await cubit.sendIsoMessage(token: 'token');

    expect(waits, [const Duration(seconds: 3), const Duration(seconds: 7)]);
    verify(
      () => repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
    ).called(2);
  });

  test(
    'UNDER_REVIEW detiene el polling sin marcar la venta rechazada',
    () async {
      final cubit = makeCubit(wait: (_) async {});
      addTearDown(cubit.close);
      openReview(cubit);
      stubRegister(_underReview);

      await cubit.sendIsoMessage(token: 'token');

      expect(cubit.state, isA<SalesAwaitingAuthorization>());
      final pending = cubit.state as SalesAwaitingAuthorization;
      expect(pending.pendingReason, PendingSaleReason.underReview);
      verifyNever(
        () => repository.getSaleStatus(
          token: any(named: 'token'),
          transactionNumber: any(named: 'transactionNumber'),
        ),
      );
    },
  );

  test('reanuda una pendiente del historial sin un segundo POST', () async {
    final cubit = makeCubit(wait: (_) async {});
    addTearDown(cubit.close);
    when(
      () => repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
    ).thenAnswer((_) async => _finalResponse(SaleAuthorizationStatus.approved));

    await cubit.resumePendingSale(
      token: 'token',
      operation: OperationModel(
        id: 'OP-1',
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 4,
        cardNumber: '•••• 7403',
        result: PaymentResult.pending,
        date: DateTime(2026),
      ),
    );

    expect(cubit.state, isA<SalesCompleted>());
    verifyNever(
      () => repository.registerSale(
        product: any(named: 'product'),
        amount: any(named: 'amount'),
        cardNumber: any(named: 'cardNumber'),
        cvv: any(named: 'cvv'),
        expirationDate: any(named: 'expirationDate'),
        token: any(named: 'token'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  test('un error transitorio conserva PENDING y vuelve a consultar', () async {
    var calls = 0;
    final cubit = makeCubit(wait: (_) async {});
    addTearDown(cubit.close);
    openReview(cubit);
    stubRegister(_pending);
    when(
      () => repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
    ).thenAnswer((_) async {
      calls += 1;
      if (calls == 1) throw const DataLoadException('Sin red');
      return _finalResponse(SaleAuthorizationStatus.approved);
    });

    await cubit.sendIsoMessage(token: 'token');

    expect(cubit.state, isA<SalesCompleted>());
    expect(calls, 2);
  });

  test('cancelar la pantalla corta el timer y conserva la pendiente', () async {
    final delayed = Completer<void>();
    final cubit = makeCubit(wait: (_) => delayed.future);
    addTearDown(cubit.close);
    openReview(cubit);
    stubRegister(_pending);

    final sending = cubit.sendIsoMessage(token: 'token');
    await Future<void>.delayed(Duration.zero);
    cubit.cancelPendingSalePolling();
    delayed.complete();
    await sending;

    expect(cubit.state, isA<SalesAwaitingAuthorization>());
    expect((cubit.state as SalesAwaitingAuthorization).pollingStopped, isTrue);
    verifyNever(
      () => repository.getSaleStatus(
        token: any(named: 'token'),
        transactionNumber: any(named: 'transactionNumber'),
      ),
    );
  });

  test('el timeout de UI deja la venta pendiente para retomarla', () async {
    var now = DateTime(2026);
    final cubit = makeCubit(
      timeout: const Duration(seconds: 3),
      now: () => now,
      wait: (duration) async => now = now.add(duration),
    );
    addTearDown(cubit.close);
    openReview(cubit);
    stubRegister(_pending);
    when(
      () => repository.getSaleStatus(token: 'token', transactionNumber: 'OP-1'),
    ).thenAnswer((_) async => _pending);

    await cubit.sendIsoMessage(token: 'token');

    expect(cubit.state, isA<SalesAwaitingAuthorization>());
    final pending = cubit.state as SalesAwaitingAuthorization;
    expect(pending.pollingStopped, isTrue);
    expect(pending.message, contains('historial'));
  });
}
