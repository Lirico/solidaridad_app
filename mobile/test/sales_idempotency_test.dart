import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/core/theme/app_colors.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_state.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_review_content.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_status_content.dart';

class MockSalesRepository extends Mock implements SalesRepository {}

const _connectionError = SaleResponse(
  isApproved: false,
  operationNumber: '',
  message: 'Tiempo de espera agotado',
  errorCode: '99',
  connectionError: true,
);

const _approved = SaleResponse(
  isApproved: true,
  operationNumber: 'OP-1',
  message: 'Aprobado',
  errorCode: '00',
);

void main() {
  late MockSalesRepository repository;
  late SalesCubit cubit;

  setUp(() {
    repository = MockSalesRepository();
    cubit = SalesCubit(salesRepository: repository);
  });

  tearDown(() => cubit.close());

  void openReview() {
    cubit.showReview(
      productCode: 'GARRAFA_10',
      productLabel: 'Garrafa 10 kg',
      amount: 4,
      cardNumber: '6063007014007403',
      cvv: '878',
      expirationDate: '1228',
    );
  }

  void stubRegisterSale(SaleResponse response) {
    when(
      () => repository.registerSale(
        product: any(named: 'product'),
        amount: any(named: 'amount'),
        cardNumber: any(named: 'cardNumber'),
        cvv: any(named: 'cvv'),
        expirationDate: any(named: 'expirationDate'),
        entryMode: any(named: 'entryMode'),
        track2: any(named: 'track2'),
        token: any(named: 'token'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => response);
  }

  test('un segundo envío en curso no registra otra venta', () async {
    openReview();
    final key = cubit.state.idempotencyKey;
    expect(key, isNotEmpty);

    final gate = Completer<SaleResponse>();
    when(
      () => repository.registerSale(
        product: any(named: 'product'),
        amount: any(named: 'amount'),
        cardNumber: any(named: 'cardNumber'),
        cvv: any(named: 'cvv'),
        expirationDate: any(named: 'expirationDate'),
        entryMode: any(named: 'entryMode'),
        track2: any(named: 'track2'),
        token: any(named: 'token'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => gate.future);

    final first = cubit.sendIsoMessage(token: 'tok');
    await Future<void>.delayed(Duration.zero);
    final second = cubit.sendIsoMessage(token: 'tok');

    gate.complete(_approved);
    await first;
    await second;

    verify(
      () => repository.registerSale(
        product: 'GARRAFA_10',
        amount: '4.0',
        cardNumber: '6063007014007403',
        cvv: '878',
        expirationDate: '1228',
        entryMode: '012',
        track2: null,
        token: 'tok',
        idempotencyKey: key,
      ),
    ).called(1);
  });

  test('el reintento por error de red reutiliza la misma clave', () async {
    openReview();
    final key = cubit.state.idempotencyKey;
    stubRegisterSale(_connectionError);

    await cubit.sendIsoMessage(token: 'tok');
    expect(cubit.state, isA<SalesCompleted>());
    expect(
      (cubit.state as SalesCompleted).result,
      PaymentResult.connectionError,
    );
    expect(cubit.state.idempotencyKey, key);

    await cubit.sendIsoMessage(token: 'tok');

    verify(
      () => repository.registerSale(
        product: 'GARRAFA_10',
        amount: '4.0',
        cardNumber: '6063007014007403',
        cvv: '878',
        expirationDate: '1228',
        entryMode: '012',
        track2: null,
        token: 'tok',
        idempotencyKey: key,
      ),
    ).called(2);
  });

  testWidgets('CONFIRMAR COBRO está deshabilitado mientras se envía', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleReviewContent(
            state: const SalesProcessing(
              productCode: 'GARRAFA_10',
              productLabel: 'Garrafa 10 kg',
              amount: 4,
              cardNumber: '6063007014007403',
              cvv: '878',
              expirationDate: '1228',
              history: [],
              idempotencyKey: 'key-1',
            ),
            onConfirm: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'CONFIRMAR COBRO'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('REINTENTAR solo aparece en error de conexión', (tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleStatusContent(
            result: PaymentResult.connectionError,
            statusColor: AppColors.primaryOrange,
            statusIcon: Icons.wifi_off_outlined,
            statusTitle: 'Error de Conexión',
            statusSubtitle: 'Reintente.',
            onRetry: () {},
            onFinalize: () {},
          ),
        ),
      ),
    );
    expect(find.text('REINTENTAR'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleStatusContent(
            result: PaymentResult.declined,
            statusColor: const Color(0xFFE74C3C),
            statusIcon: Icons.error_outline,
            statusTitle: 'Transacción Rechazada',
            statusSubtitle: 'Rechazada.',
            onFinalize: () {},
          ),
        ),
      ),
    );
    expect(find.text('REINTENTAR'), findsNothing);
    expect(find.text('FINALIZAR'), findsOneWidget);
  });
}
