import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/core/widgets/app_bottom_nav_bar.dart';
import 'package:solidaridad_app/core/widgets/app_header.dart';
import 'package:solidaridad_app/core/widgets/app_sheet_panel.dart';

/// Cabecera + cajón blanco + barra inferior (mismo template de las pantallas)
/// al tamaño del device usado en QA (720x1440 px @2x → 360x720 dp).
Future<void> _pumpTemplate(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1440);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        appBar: AppHeader(title: 'Nueva Operación'),
        bottomNavigationBar: AppBottomNavBar(),
        body: AppSheetPanel(child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('⋯ Más abre un panel que cubre exactamente el área del cajón blanco', (
    tester,
  ) async {
    await _pumpTemplate(tester);

    final sheetRect = tester.getRect(find.byType(AppSheetPanel).first);

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final menuRect = tester.getRect(find.byKey(const Key('moreMenuSheet')));
    // Ocupa el 100% del ancho…
    expect(menuRect.left, sheetRect.left);
    expect(menuRect.right, sheetRect.right);
    // …arranca tras la franja naranja de 10dp bajo la cabecera…
    expect(menuRect.top, sheetRect.top + AppSheetPanel.topGap);
    // …y termina pegado al borde superior de la barra inferior (tolerancia de
    // 1px por el borde/safe-area del entorno de layout).
    expect(menuRect.bottom, closeTo(sheetRect.bottom, 1));
  });

  testWidgets('⋯ Más: el panel no desborda, muestra las opciones y se cierra', (
    tester,
  ) async {
    await _pumpTemplate(tester);

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moreMenuSheet')), findsOneWidget);
    expect(find.text('Más opciones'), findsOneWidget);
    expect(find.text('Consultar saldo'), findsOneWidget);
    expect(find.text('Cerrar Lote'), findsOneWidget);
    expect(find.text('Historial de ventas'), findsOneWidget);
    expect(find.text('CERRAR'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Las opciones deshabilitadas no cierran el panel al tocarlas.
    await tester.tap(find.text('Consultar saldo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moreMenuSheet')), findsOneWidget);

    // CERRAR cierra el panel.
    await tester.tap(find.text('CERRAR'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moreMenuSheet')), findsNothing);
    expect(find.text('Más opciones'), findsNothing);
  });

  testWidgets('⋯ Más: tocar fuera del panel lo cierra', (tester) async {
    await _pumpTemplate(tester);

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moreMenuSheet')), findsOneWidget);

    // Zona fuera del panel (franja naranja bajo la cabecera).
    await tester.tapAt(const Offset(180, 70));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moreMenuSheet')), findsNothing);
  });
}
