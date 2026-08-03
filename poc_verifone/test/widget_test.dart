import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poc_verifone/main.dart';

void main() {
  testWidgets('counter increments on Sumar tap', (WidgetTester tester) async {
    await tester.pumpWidget(const PocVerifoneApp());

    expect(find.textContaining('Contador: 0'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sumar'));
    await tester.pump();

    expect(find.textContaining('Contador: 1'), findsOneWidget);
  });
}
