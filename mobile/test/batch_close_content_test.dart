import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/core/theme/app_colors.dart';
import 'package:solidaridad_app/core/theme/app_theme.dart';
import 'package:solidaridad_app/core/widgets/app_bottom_nav_bar.dart';
import 'package:solidaridad_app/core/widgets/app_header.dart';
import 'package:solidaridad_app/core/widgets/app_sheet_panel.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/batch_close/domain/batch_close_model.dart';
import 'package:solidaridad_app/features/batch_close/presentation/screens/batch_close_screen.dart';
import 'package:solidaridad_app/features/batch_close/presentation/widgets/batch_close_content.dart';

/// Resumen equivalente al del mockup del cliente.
BatchSummary _mockupSummary({bool isPartial = false}) {
  return BatchSummary(
    batchNumber: '000123',
    salesCount: 45,
    totalKg: 2055,
    isPartial: isPartial,
    products: const [
      BatchProductItem(
        productCode: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        quantity: 15,
        kg: 150,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GARRAFA_15',
        label: 'Garrafa 15 kg',
        quantity: 10,
        kg: 150,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GARRAFA_30',
        label: 'Garrafa 30 kg',
        quantity: 8,
        kg: 240,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'TUBO_45',
        label: 'Tubo 45 kg',
        quantity: 7,
        kg: 315,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GRANEL',
        label: 'Granel',
        quantity: 1200,
        kg: 1200,
        unitLabel: 'm³',
      ),
    ],
  );
}

/// Atajo: pantalla real con el template (cabecera + panel + barra inferior).
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1440);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: BlocProvider<AuthCubit>.value(
        value: AuthCubit(authRepository: AuthRepository()),
        child: const BatchCloseScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Monta el contenido dentro del template real (cabecera 64dp + panel blanco +
/// barra inferior) al tamaño del device de QA: 720×1440 px @2x → 360×720 dp.
Future<void> _pumpContent(
  WidgetTester tester,
  BatchSummary summary, {
  VoidCallback? onCloseBatch,
}) async {
  tester.view.physicalSize = const Size(720, 1440);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        backgroundColor: AppColors.primaryOrange,
        appBar: const AppHeader(title: 'Cierre de Lote'),
        bottomNavigationBar: const AppBottomNavBar(),
        body: AppSheetPanel(
          child: BatchCloseContent(
            summary: summary,
            onCloseBatch: onCloseBatch ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('el contenido muestra el lote, el resumen y los productos', (
    tester,
  ) async {
    await _pumpContent(tester, _mockupSummary());

    expect(find.text('Lote Actual'), findsOneWidget);
    expect(find.text('000123'), findsOneWidget);
    expect(find.text('Resumen de Ventas'), findsOneWidget);
    expect(find.text('Cantidad de Ventas'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('Total de Ventas'), findsOneWidget);
    expect(find.text('2.055 kg'), findsOneWidget);
    expect(find.text('Ventas por Producto'), findsOneWidget);

    // Una fila por producto, con su cantidad y su equivalente en kg.
    expect(find.byIcon(Icons.propane_tank_outlined), findsNWidgets(5));
    expect(find.text('Garrafa 10 kg'), findsOneWidget);
    expect(find.text('150 Kg'), findsNWidgets(2));
    expect(find.text('240 Kg'), findsOneWidget);
    expect(find.text('315 Kg'), findsOneWidget);
    expect(find.text('1.200 Kg'), findsOneWidget);

    expect(find.text('CERRAR LOTE'), findsOneWidget);
    // Regla del alcance: las pantallas operativas entran en 360×720 sin
    // desbordar ni cortar contenido.
    expect(tester.takeException(), isNull);
  });

  testWidgets('CERRAR LOTE dispara el callback del contenido', (tester) async {
    int closes = 0;
    await _pumpContent(tester, _mockupSummary(), onCloseBatch: () => closes++);

    await tester.tap(find.text('CERRAR LOTE'));
    await tester.pumpAndSettle();

    expect(closes, 1);
  });

  testWidgets('sin ventas muestra el mensaje vacío y no desborda', (
    tester,
  ) async {
    await _pumpContent(
      tester,
      const BatchSummary(
        batchNumber: '000001',
        salesCount: 0,
        totalKg: 0,
        products: [],
      ),
    );

    expect(find.text('No hay ventas registradas en el lote.'), findsOneWidget);
    expect(find.text('0 kg'), findsOneWidget);
    expect(find.text('CERRAR LOTE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un resumen parcial avisa que puede estar incompleto', (
    tester,
  ) async {
    await _pumpContent(tester, _mockupSummary(isPartial: true));

    expect(find.textContaining('puede estar incompleto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la pantalla del prototipo muestra los datos de ejemplo', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Cierre de Lote'), findsOneWidget);
    expect(find.text('000123'), findsOneWidget);
    expect(find.text('Garrafa 10 kg'), findsOneWidget);
    expect(find.text('Granel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // El botón está habilitado (como el mockup) aunque todavía no cierre nada.
    final ElevatedButton closeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'CERRAR LOTE'),
    );
    expect(closeButton.onPressed, isNotNull);
  });
}
