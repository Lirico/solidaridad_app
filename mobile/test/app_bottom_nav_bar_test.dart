import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solidaridad_app/core/widgets/app_bottom_nav_bar.dart';

void main() {
  testWidgets('AppBottomNavBar muestra ← atrás, VENTA y ⋯ más', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: AppBottomNavBar(),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('VENTA'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('AppBottomNavBar deshabilitado muestra las tres zonas inertes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: AppBottomNavBar(enabled: false),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('VENTA'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    // La flecha está deshabilitada: no navega.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('VENTA'), findsOneWidget);
  });

  testWidgets(
      'el menú "más" muestra Consultar saldo, Cerrar Lote e Historial de ventas',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: AppBottomNavBar(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Consultar saldo'), findsOneWidget);
    expect(find.text('Cerrar Lote'), findsOneWidget);
    expect(find.text('Historial de ventas'), findsOneWidget);
    // El cambio de contraseña NO vive en el menú "más".
    expect(find.text('Cambiar Contraseña'), findsNothing);
  });
}
