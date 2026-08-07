import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../domain/sale_model.dart';
import '../widgets/sale_review_header.dart';
import '../widgets/sale_status_content.dart';

class SaleStatusScreen extends StatelessWidget {
  const SaleStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PaymentResult result =
        (ModalRoute.of(context)?.settings.arguments as PaymentResult?) ??
        PaymentResult.approved;

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    switch (result) {
      case PaymentResult.approved:
        statusColor = const Color(0xFF2ECC71);
        statusIcon = Icons.check_circle_outline;
        statusTitle = '¡Transacción Aprobada!';
        statusSubtitle = 'El mensaje ISO fue procesado con éxito por AWS.';
      case PaymentResult.declined:
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.error_outline;
        statusTitle = 'Transacción Rechazada';
        statusSubtitle = 'La terminal reportó un error en la autorización.';
      case PaymentResult.connectionError:
        statusColor = const Color(0xFFFF8C00);
        statusIcon = Icons.wifi_off_outlined;
        statusTitle = 'Error de Conexión';
        statusSubtitle =
            'No se pudo contactar con el POSNET. Verifique su conectividad y reintente.';
      case PaymentResult.voided:
        statusColor = Colors.grey;
        statusIcon = Icons.undo;
        statusTitle = 'Transacción Anulada';
        statusSubtitle = 'La venta fue anulada correctamente.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 👑 REUTILIZADO: Usamos el mismo header base sin botón de volver
            const SaleReviewHeader(title: 'Resultado del Cobro'),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SaleStatusContent(
                      result: result,
                      statusColor: statusColor,
                      statusIcon: statusIcon,
                      statusTitle: statusTitle,
                      statusSubtitle: statusSubtitle,
                      onFinalize: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.saleForm,
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
