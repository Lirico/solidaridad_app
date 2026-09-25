import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/cubit/sales_cubit.dart';
import '../../../sales/presentation/widgets/sale_status_content.dart';

class VoidResultScreen extends StatefulWidget {
  const VoidResultScreen({super.key});

  @override
  State<VoidResultScreen> createState() => _VoidResultScreenState();
}

class _VoidResultScreenState extends State<VoidResultScreen> {
  bool _consulting = false;

  Future<void> _consult(OperationModel operation) async {
    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthSuccess ? authState.user : null;
    if (user == null) return;

    setState(() => _consulting = true);
    try {
      final fresh = await context.read<SalesCubit>().fetchTransaction(
        token: user.token,
        transactionNumber: operation.id,
      );
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.saleDetail,
        arguments: fresh,
      );
    } on SessionExpiredException {
      if (!mounted) return;
      context.read<AuthCubit>().logout();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo consultar el estado de la operación.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _consulting = false);
    }
  }

  void _retry(OperationModel operation) {
    Navigator.pushNamed(context, AppRoutes.voidCard, arguments: operation);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final VoidStatusArgs? statusArgs = args is VoidStatusArgs ? args : null;
    final VoidResult result =
        statusArgs?.result ??
        (args is VoidResult ? args : const VoidResult.voided());
    final OperationModel? operation = statusArgs?.operation;

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;
    final PaymentResult displayResult;

    if (result.isVoided) {
      statusColor = Colors.grey;
      statusIcon = Icons.undo;
      statusTitle = '¡Anulación Aprobada!';
      statusSubtitle = result.message;
      displayResult = PaymentResult.voided;
    } else if (result.isDeclined) {
      statusColor = const Color(0xFFE74C3C);
      statusIcon = Icons.error_outline;
      statusTitle = 'Anulación Rechazada';
      statusSubtitle = result.message;
      displayResult = PaymentResult.declined;
    } else if (result.isUnknown) {
      statusColor = const Color(0xFFE67E22);
      statusIcon = Icons.help_outline;
      statusTitle = 'No se pudo confirmar';
      statusSubtitle = result.message;
      displayResult = PaymentResult.unknown;
    } else {
      statusColor = const Color(0xFFFF8C00);
      statusIcon = Icons.wifi_off_outlined;
      statusTitle = 'Error de Conexión';
      statusSubtitle = result.message;
      displayResult = PaymentResult.connectionError;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SaleStatusContent(
                  result: displayResult,
                  statusColor: statusColor,
                  statusIcon: statusIcon,
                  statusTitle: statusTitle,
                  statusSubtitle: statusSubtitle,
                  operation: operation,
                  onFinalize: () {
                    Navigator.popUntil(
                      context,
                      (route) => route.settings.name == AppRoutes.salesHistory,
                    );
                  },
                ),
              ),
              if (result.isUnknown && operation != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _consulting ? null : () => _consult(operation),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primaryOrange),
                  ),
                  child: Text(
                    _consulting ? 'CONSULTANDO...' : 'CONSULTAR ESTADO',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _consulting ? null : () => _retry(operation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'REINTENTAR ANULACIÓN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
