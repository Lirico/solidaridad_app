import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_status_screen.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/sale_status_content.dart';

void main() {
  test('el fallback de conexión no invita a reintentar el cobro', () {
    expect(saleConnectionSubtitle(null), kSalePendingConfirmationMessage);
    expect(saleConnectionSubtitle('   '), kSalePendingConfirmationMessage);
    expect(
      saleConnectionSubtitle(kSalePendingConfirmationMessage).toLowerCase(),
      isNot(contains('reintente')),
    );
    expect(
      saleConnectionSubtitle(
        'No se pudo establecer conexión con el servidor. Verifique su red.',
      ),
      contains('Verifique su red'),
    );
  });

  testWidgets('un cobro pendiente muestra el aviso y solo ofrece FINALIZAR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleStatusContent(
            result: PaymentResult.connectionError,
            statusColor: const Color(0xFFFF8C00),
            statusIcon: Icons.wifi_off_outlined,
            statusTitle: 'Error de Conexión',
            statusSubtitle: saleConnectionSubtitle(
              kSalePendingConfirmationMessage,
            ),
            operation: OperationModel(
              id: 'OP-ERR',
              productCode: 'GARRAFA_10',
              productLabel: 'Garrafa 10 kg',
              amount: 1,
              cardNumber: '•••• 7403',
              result: PaymentResult.connectionError,
              date: DateTime(2026, 9, 23),
              userMessage: kSalePendingConfirmationMessage,
            ),
            onFinalize: () {},
          ),
        ),
      ),
    );

    expect(find.text(kSalePendingConfirmationMessage), findsOneWidget);
    expect(find.textContaining('reintente'), findsNothing);
    expect(find.textContaining('Reintente'), findsNothing);
    expect(find.text('FINALIZAR'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsNothing);
  });
}
