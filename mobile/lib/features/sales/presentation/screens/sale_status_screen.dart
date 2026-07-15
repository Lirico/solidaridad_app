import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../widgets/sale_review_header.dart';
import '../widgets/sale_status_content.dart';

class SaleStatusScreen extends StatelessWidget {
  const SaleStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSuccess =
        (ModalRoute.of(context)?.settings.arguments as bool?) ?? true;

    final Color statusColor = isSuccess
        ? const Color(0xFF2ECC71)
        : const Color(0xFFE74C3C);
    final IconData statusIcon = isSuccess
        ? Icons.check_circle_outline
        : Icons.error_outline;
    final String statusTitle = isSuccess
        ? '¡Transacción Aprobada!'
        : 'Transacción Rechazada';
    final String statusSubtitle = isSuccess
        ? 'El mensaje ISO fue procesado con éxito por AWS.'
        : 'La terminal reportó un error en la autorización.';

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
                      isSuccess: isSuccess,
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
