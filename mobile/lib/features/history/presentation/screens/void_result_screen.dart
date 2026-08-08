import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/widgets/sale_review_header.dart';
import '../../../sales/presentation/widgets/sale_status_content.dart';

class VoidResultScreen extends StatelessWidget {
  const VoidResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final VoidResult result =
        (args is VoidResult ? args : const VoidResult.voided());

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    if (result.isVoided) {
      statusColor = Colors.grey;
      statusIcon = Icons.undo;
      statusTitle = '¡Anulación Aprobada!';
      statusSubtitle = result.message;
    } else if (result.isDeclined) {
      statusColor = const Color(0xFFE74C3C);
      statusIcon = Icons.error_outline;
      statusTitle = 'Anulación Rechazada';
      statusSubtitle = result.message;
    } else if (result.isUnknown) {
      statusColor = const Color(0xFFE67E22);
      statusIcon = Icons.help_outline;
      statusTitle = 'No se pudo confirmar';
      statusSubtitle = result.message;
    } else {
      statusColor = const Color(0xFFFF8C00);
      statusIcon = Icons.wifi_off_outlined;
      statusTitle = 'Error de Conexión';
      statusSubtitle = result.message;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SaleReviewHeader(title: 'Resultado de la Anulación'),
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
                      result: PaymentResult.voided,
                      statusColor: statusColor,
                      statusIcon: statusIcon,
                      statusTitle: statusTitle,
                      statusSubtitle: statusSubtitle,
                      onFinalize: () {
                        Navigator.popUntil(
                          context,
                          (route) => route.settings.name == AppRoutes.salesHistory,
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