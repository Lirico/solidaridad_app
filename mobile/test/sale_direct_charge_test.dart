import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:solidaridad_app/core/constants/app_routes.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_manual_card_screen.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_waiting_for_card_screen.dart';
import 'package:solidaridad_app/psdk/msr_card_data.dart';
import 'package:solidaridad_app/psdk/psdk_card_reader.dart';

class MockSalesRepository extends Mock implements SalesRepository {}

class MockPsdkCardReader extends Mock implements PsdkCardReader {}

class _FixedAuthCubit extends AuthCubit {
  _FixedAuthCubit() : super(authRepository: AuthRepository());

  void force(AuthState state) => emit(state);
}

const _approved = SaleResponse(
  isApproved: true,
  operationNumber: 'OP-1',
  message: 'Aprobado',
  errorCode: '00',
);

void _stubRegisterSale(
  MockSalesRepository repository,
  Future<SaleResponse> response,
) {
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
  ).thenAnswer((_) => response);
}

Future<void> _pumpSaleScreen(
  WidgetTester tester, {
  required Widget screen,
  required SalesCubit salesCubit,
}) async {
  final authCubit = _FixedAuthCubit()
    ..force(
      const AuthSuccess(
        user: User(name: 'Operador', email: 'operador@test.com', token: 'tok'),
      ),
    );
  addTearDown(authCubit.close);
  addTearDown(salesCubit.close);

  salesCubit.setProductAndAmount(
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<SalesCubit>.value(value: salesCubit),
      ],
      child: MaterialApp(
        routes: {
          AppRoutes.saleProcessing: (_) =>
              const Scaffold(body: Text('procesando directo')),
        },
        home: screen,
      ),
    ),
  );
}

void main() {
  testWidgets('manual cobra directo y dos toques generan un solo envío', (
    tester,
  ) async {
    final repository = MockSalesRepository();
    final cubit = SalesCubit(salesRepository: repository);
    final gate = Completer<SaleResponse>();
    _stubRegisterSale(repository, gate.future);

    await _pumpSaleScreen(
      tester,
      screen: const SaleManualCardScreen(),
      salesCubit: cubit,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '6063007014007403');
    await tester.enterText(fields.at(1), '1228');
    await tester.enterText(fields.at(2), '878');

    final chargeButton = find.widgetWithText(ElevatedButton, 'COBRAR');
    final onPressed = tester.widget<ElevatedButton>(chargeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(find.text('procesando directo'), findsOneWidget);
    expect(find.text('Confirmar Operación'), findsNothing);

    final calls = verify(
      () => repository.registerSale(
        product: 'GARRAFA_10',
        amount: '4.0',
        cardNumber: '6063 0070 1400 7403',
        cvv: '878',
        expirationDate: '2812',
        token: 'tok',
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    );
    calls.called(1);
    expect(calls.captured.single, isNotEmpty);

    gate.complete(_approved);
    await tester.pump();
  });

  testWidgets('banda cobra directo sin abrir confirmación', (tester) async {
    final repository = MockSalesRepository();
    final cubit = SalesCubit(salesRepository: repository);
    final reader = MockPsdkCardReader();
    _stubRegisterSale(repository, Future.value(_approved));
    when(() => reader.readCard()).thenAnswer(
      (_) async => const CardReadSuccess(
        MsrCardData(
          pan: '6063007014007403',
          expiryYyMm: '2812',
          track2: '6063007014007403=2812101',
        ),
      ),
    );
    when(() => reader.cancel()).thenAnswer((_) async {});

    await _pumpSaleScreen(
      tester,
      screen: WaitingForCardScreen(reader: reader),
      salesCubit: cubit,
    );
    await tester.pumpAndSettle();

    expect(find.text('procesando directo'), findsOneWidget);
    expect(find.text('Confirmar Operación'), findsNothing);
    verify(
      () => repository.registerSale(
        product: 'GARRAFA_10',
        amount: '4.0',
        cardNumber: '6063007014007403',
        cvv: '',
        expirationDate: '2812',
        token: 'tok',
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });
}
