import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_status_screen.dart';

void main() {
  testWidgets('sin datos no muestra la venta como aprobada y vuelve atrás', (
    tester,
  ) async {
    await _openStatus(tester);

    expect(
      find.text('No hay datos de la operación disponibles'),
      findsOneWidget,
    );
    expect(find.text('¡Transacción Aprobada!'), findsNothing);

    await tester.pump();
    expect(find.text('abrir'), findsOneWidget);
    expect(find.text('¡Transacción Aprobada!'), findsNothing);
  });

  testWidgets('un argumento de otro tipo tampoco se muestra como aprobada', (
    tester,
  ) async {
    await _openStatus(tester, arguments: 'no-es-operacion');

    expect(
      find.text('No hay datos de la operación disponibles'),
      findsOneWidget,
    );
    expect(find.text('¡Transacción Aprobada!'), findsNothing);
  });

  testWidgets('con un rechazo muestra Transacción Rechazada', (tester) async {
    await _openStatus(
      tester,
      arguments: OperationModel(
        id: 'OP-1',
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 4,
        cardNumber: '**** **** **** 7403',
        result: PaymentResult.declined,
        date: DateTime(2026, 9, 28),
      ),
    );

    expect(find.text('Transacción Rechazada'), findsOneWidget);
    expect(find.text('No hay datos de la operación disponibles'), findsNothing);
    expect(find.text('¡Transacción Aprobada!'), findsNothing);
  });
}

Future<void> _openStatus(WidgetTester tester, {Object? arguments}) async {
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => AuthCubit(authRepository: AuthRepository()),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder<void>(
                    settings: RouteSettings(arguments: arguments),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, __, ___) => const SaleStatusScreen(),
                  ),
                );
              },
              child: const Text('abrir'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
}
