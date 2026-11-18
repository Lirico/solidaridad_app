import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/merchant_store.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_status_screen.dart';

class _MerchantCubit extends AuthCubit {
  _MerchantCubit()
    : super(
        authRepository: AuthRepository(),
        merchantStore: MerchantStore()..replace(_merchant),
      ) {
    emit(
      const AuthSuccess(
        user: User(name: 'Ana', email: 'ana@comercio.test', token: 'tok'),
        merchant: _merchant,
      ),
    );
  }
}

const _merchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
);

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
    const channel = MethodChannel('com.solidaridad.poc_verifone/psdk');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getStatus') {
        return <String, dynamic>{'sdiReady': true};
      }
      if (call.method == 'printHtml') {
        return <String, dynamic>{'ok': true};
      }
      return <String, dynamic>{'ok': true};
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await _openStatus(
      tester,
      cubit: _MerchantCubit(),
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

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _openStatus(
  WidgetTester tester, {
  Object? arguments,
  AuthCubit? cubit,
}) async {
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => cubit ?? AuthCubit(authRepository: AuthRepository()),
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
                    pageBuilder: (_, _, _) => const SaleStatusScreen(),
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
