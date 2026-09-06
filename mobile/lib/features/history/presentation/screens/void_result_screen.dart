import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/widgets/sale_status_content.dart';

class VoidResultScreen extends StatelessWidget {
  const VoidResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final VoidResult result = (args is VoidResult
        ? args
        : const VoidResult.voided());

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
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Resultado de la Anulación',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      // Sin flecha atrás: la salida es FINALIZAR / VENTA / ⋯.
      bottomNavigationBar: const AppBottomNavBar(hideBack: true),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
    );
  }
}
