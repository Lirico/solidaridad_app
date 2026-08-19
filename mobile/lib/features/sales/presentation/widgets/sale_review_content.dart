import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/sales_state.dart';
import 'sale_review_widgets.dart';

class SaleReviewContent extends StatelessWidget {
  final SalesState state;
  final VoidCallback onConfirm;

  const SaleReviewContent({
    super.key,
    required this.state,
    required this.onConfirm,
  });

  /// Formatea la cantidad de gas según el tipo de producto.
  ///
  /// - Garrafas y tubos se expresan como unidades.
  /// - El granel se expresa en metros cúbicos (m³).
  String _formatQuantity(SalesState state) {
    final amount = _formatNumber(state.amount);
    if (state.productCode == 'GRANEL') {
      return '$amount m³';
    }
    return '$amount unidades';
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Enmascara el número de tarjeta mostrando solo los últimos 4 dígitos,
  /// para no exponer el PAN completo en la pantalla de revisión.
  String _maskCardNumber(String cardNumber) {
    final digits = cardNumber.replaceAll(' ', '');
    if (digits.length < 4) return '•••• •••• •••• 4321';
    return '•••• •••• •••• ${digits.substring(digits.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Verifique los datos antes de proceder al cobro en la terminal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),

        ReviewDataRow(
          icon: Icons.monetization_on_outlined,
          label: 'Producto',
          value: state.productLabel,
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.local_gas_station_outlined,
          label: 'Cantidad de Gas',
          value: _formatQuantity(state),
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.credit_card_outlined,
          label: 'Número de Tarjeta',
          value: state.cardNumber.isEmpty
              ? '•••• •••• •••• 4321'
              : _maskCardNumber(state.cardNumber),
        ),

        const SizedBox(height: 56),

        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'CONFIRMAR COBRO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
