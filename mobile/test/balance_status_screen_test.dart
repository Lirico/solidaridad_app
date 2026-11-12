import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/balance/data/balance_repository.dart';
import 'package:solidaridad_app/features/balance/domain/balance_model.dart';
import 'package:solidaridad_app/features/balance/presentation/cubit/balance_cubit.dart';
import 'package:solidaridad_app/features/balance/presentation/cubit/balance_state.dart';
import 'package:solidaridad_app/features/balance/presentation/screens/balance_status_screen.dart';
import 'package:solidaridad_app/features/sales/data/receipt_printer.dart';

class _Client extends Fake implements http.Client {}

class _SeededBalanceCubit extends BalanceCubit {
  _SeededBalanceCubit(BalanceState state)
    : super(repository: BalanceRepository(httpClient: _Client())) {
    emit(state);
  }
}

void main() {
  testWidgets('una consulta aprobada imprime el ticket una sola vez', (
    tester,
  ) async {
    final printed = <double>[];
    final cubit = _SeededBalanceCubit(
      const BalanceCompleted(
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        result: BalanceResult(
          status: BalanceStatus.approved,
          balances: [
            BalanceItem(
              product: 'GARRAFA_10',
              label: 'Garrafa 10 kg',
              availableBalance: 10.1,
            ),
          ],
          message: 'Consulta de saldo exitosa',
        ),
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(authRepository: AuthRepository()),
          ),
          BlocProvider<BalanceCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: BalanceStatusScreen(
            printReceipt:
                ({
                  required DateTime date,
                  required String cardNumber,
                  required String expirationDate,
                  required double kilograms,
                }) async {
                  printed.add(kilograms);
                  return const PrintResult.success();
                },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Saldo disponible'), findsOneWidget);
    expect(find.text('Ticket impreso'), findsOneWidget);
    expect(printed, hasLength(1));
    expect(printed.single, closeTo(101, 0.001));
  });

  testWidgets('una consulta rechazada no imprime', (tester) async {
    var prints = 0;
    final cubit = _SeededBalanceCubit(
      const BalanceCompleted(
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        result: BalanceResult(
          status: BalanceStatus.declined,
          balances: [],
          message: 'Tarjeta inexistente',
        ),
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(authRepository: AuthRepository()),
          ),
          BlocProvider<BalanceCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: BalanceStatusScreen(
            printReceipt:
                ({
                  required DateTime date,
                  required String cardNumber,
                  required String expirationDate,
                  required double kilograms,
                }) async {
                  prints += 1;
                  return const PrintResult.success();
                },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Consulta Rechazada'), findsOneWidget);
    expect(prints, 0);
  });
}
