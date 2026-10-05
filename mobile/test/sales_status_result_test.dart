import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_status_content.dart';

final nullDate = DateTime(2026, 9, 24);

void main() {
  testWidgets('un rechazo muestra el mensaje del servidor y no el código 51', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final operation = OperationModel(
      id: 'OP-9',
      productCode: 'GARRAFA_10',
      productLabel: 'Garrafa 10 kg',
      amount: 4,
      cardNumber: '•••• 7403',
      result: PaymentResult.declined,
      date: nullDate,
      userMessage: 'Tarjeta vencida',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleStatusContent(
            result: PaymentResult.declined,
            statusColor: const Color(0xFFE74C3C),
            statusIcon: Icons.error_outline,
            statusTitle: 'Transacción Rechazada',
            statusSubtitle: 'Tarjeta vencida',
            operation: operation,
            onFinalize: () {},
          ),
        ),
      ),
    );

    expect(find.text('Tarjeta vencida'), findsWidgets);
    expect(find.text('51 (Fondos insuficientes)'), findsNothing);
  });

  testWidgets('un cobro sin confirmar no ofrece reintentar', (tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleStatusContent(
            result: PaymentResult.unknown,
            statusColor: const Color(0xFFB9770E),
            statusIcon: Icons.help_outline,
            statusTitle: 'No pudimos confirmar el cobro',
            statusSubtitle: 'Consulte la operación.',
            onViewOperation: () {},
            onFinalize: () {},
          ),
        ),
      ),
    );

    expect(find.text('VER OPERACIÓN'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsNothing);
    expect(find.text('FINALIZAR'), findsOneWidget);
  });
}
