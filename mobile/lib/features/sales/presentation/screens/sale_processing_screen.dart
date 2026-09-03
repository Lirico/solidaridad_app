import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../domain/sale_model.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';

class SaleProcessingScreen extends StatelessWidget {
  const SaleProcessingScreen({super.key});

  String _maskCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
  }

  String _formatAmount(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final salesState = context.watch<SalesCubit>().state;

    // Listen for completion and navigate away
    if (salesState is SalesCompleted) {
      // Use addPostFrameCallback to avoid building during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final operation = OperationModel(
          id: salesState.operationNumber ?? 'OP-ERR',
          productCode: salesState.productCode,
          productLabel: salesState.productLabel,
          amount: salesState.amount,
          cardNumber: _maskCardNumber(salesState.cardNumber),
          result: salesState.result,
          date: DateTime.now(),
          userMessage: salesState.errorMessage,
        );
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.saleStatus,
          arguments: operation,
        );
      });
    }

    // Session expired (401): log out and return to login
    if (salesState is SalesSessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<AuthCubit>().logout();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      });
    }

    final String productLabel = salesState.productLabel;
    final double amount = salesState.amount;
    final String cardNumber = salesState.cardNumber;

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Procesando Transacción',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      // Durante el procesamiento no se permite volver ni iniciar otra acción.
      bottomNavigationBar: const AppBottomNavBar(
        enabled: false,
        hideBack: true,
      ),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner animado grande
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Monto grande y visible
              Text(
                _formatAmount(amount),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                productLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),

              // Datos de la tarjeta
              if (cardNumber.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.credit_card, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _maskCardNumber(cardNumber),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Línea divisoria decorativa
              Container(height: 1, width: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),

              // Mensaje de advertencia
              const Text(
                'Procesando Transacción...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Estamos autorizando el pago.\n'
                'Por favor, no cierre la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
