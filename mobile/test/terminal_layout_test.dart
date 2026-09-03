import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/core/theme/app_colors.dart';
import 'package:solidaridad_app/core/widgets/app_bottom_nav_bar.dart';
import 'package:solidaridad_app/core/widgets/app_header.dart';
import 'package:solidaridad_app/core/widgets/app_sheet_panel.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/screens/change_password_screen.dart';
import 'package:solidaridad_app/features/auth/presentation/screens/login_screen.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_state.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_processing_screen.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_review_content.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_status_content.dart';

/// Cubit de test que permite fijar un estado sin pasar por la red.
class _FixedSalesCubit extends SalesCubit {
  _FixedSalesCubit() : super(salesRepository: SalesRepository());

  void force(SalesState state) => emit(state);
}

/// Monta el template real de las pantallas interactivas (AppBar compacto +
/// panel blanco a sangre completa + barra inferior) al tamaño del device usado
/// en QA (720x1440 px a densidad 2 → 360x720 dp).
Future<void> pumpAtTerminalSize(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(720, 1440);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

Widget _terminalScaffold({required String title, required Widget card}) {
  return Scaffold(
    backgroundColor: AppColors.primaryOrange,
    appBar: AppHeader(title: title),
    bottomNavigationBar: const AppBottomNavBar(),
    body: AppSheetPanel(
      child: Padding(padding: const EdgeInsets.all(24), child: card),
    ),
  );
}

SalesReviewing _reviewState() {
  return const SalesReviewing(
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 10.0,
    cardNumber: '1234 5678 9012 3456',
    cvv: '123',
    expirationDate: '1229',
    history: [],
  );
}

OperationModel _operation() {
  return OperationModel(
    id: 'OP-001',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 10.0,
    cardNumber: '**** **** **** 3456',
    result: PaymentResult.approved,
    date: DateTime(2026, 9, 2),
  );
}

void main() {
  testWidgets(
    'cabecera + tarjeta inferior: título y logo entran en 360 de ancho',
    (tester) async {
      await pumpAtTerminalSize(
        tester,
        Scaffold(
          appBar: AppHeader(title: 'Historial de Ventas'),
          body: const SizedBox.expand(),
        ),
      );

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Historial de Ventas'), findsOneWidget);
    },
  );

  testWidgets('Confirmar Operación no desborda en 360x720', (tester) async {
    await pumpAtTerminalSize(
      tester,
      _terminalScaffold(
        title: 'Confirmar Operación',
        card: SaleReviewContent(state: _reviewState(), onConfirm: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('CONFIRMAR COBRO'), findsOneWidget);
  });

  testWidgets('Procesando Transacción no desborda en 360x720', (tester) async {
    final salesCubit = _FixedSalesCubit()
      ..force(
        const SalesProcessing(
          productCode: 'GARRAFA_10',
          productLabel: 'Garrafa 10 kg',
          amount: 1500.0,
          cardNumber: '1234 5678 9012 3456',
          cvv: '123',
          expirationDate: '1229',
          history: [],
        ),
      );

    await pumpAtTerminalSize(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<SalesCubit>.value(value: salesCubit),
          BlocProvider<AuthCubit>.value(
            value: AuthCubit(authRepository: AuthRepository()),
          ),
        ],
        child: const SaleProcessingScreen(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Procesando Transacción...'), findsOneWidget);
  });

  testWidgets('Resultado del Cobro no desborda en 360x720', (tester) async {
    await pumpAtTerminalSize(
      tester,
      _terminalScaffold(
        title: 'Resultado del Cobro',
        card: SaleStatusContent(
          result: PaymentResult.approved,
          statusColor: const Color(0xFF2ECC71),
          statusIcon: Icons.check_circle_outline,
          statusTitle: '¡Transacción Aprobada!',
          statusSubtitle: 'El pago fue autorizado correctamente.',
          operation: _operation(),
          onFinalize: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('FINALIZAR'), findsOneWidget);
  });

  testWidgets('Resultado de la Anulación no desborda en 360x720', (
    tester,
  ) async {
    await pumpAtTerminalSize(
      tester,
      _terminalScaffold(
        title: 'Resultado de la Anulación',
        card: SaleStatusContent(
          result: PaymentResult.voided,
          statusColor: Colors.grey,
          statusIcon: Icons.undo,
          statusTitle: '¡Anulación Aprobada!',
          statusSubtitle: 'Anulación aprobada',
          onFinalize: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('FINALIZAR'), findsOneWidget);
  });

  testWidgets('AppHeader define una cabecera de 64dp', (tester) async {
    const header = AppHeader(title: 'Nueva Operación');
    expect(header.preferredSize.height, 64);
  });

  testWidgets('Actualizar Contraseña: cabecera 64dp y sin solape en 360x720', (
    tester,
  ) async {
    await pumpAtTerminalSize(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(
            value: AuthCubit(authRepository: AuthRepository()),
          ),
        ],
        child: const ChangePasswordScreen(),
      ),
    );

    final header = tester.widget<AppHeader>(find.byType(AppHeader));
    expect(header.preferredSize.height, 64);
    expect(tester.takeException(), isNull);
    expect(find.text('CONFIRMAR CAMBIO'), findsOneWidget);
  });

  testWidgets('Login: logo SOLIDARIDAD agrandado no desborda en 360x720', (
    tester,
  ) async {
    await pumpAtTerminalSize(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(
            value: AuthCubit(authRepository: AuthRepository()),
          ),
        ],
        child: const LoginScreen(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ingresar a su Cuenta'), findsOneWidget);
  });
}
