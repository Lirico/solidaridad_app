import 'package:flutter/material.dart';
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
  /// - Garrafas y tubos se expresan en kilogramos (kg).
  /// - El granel se expresa en metros cúbicos (m³) y litros (L), ya que según
  ///   el proveedor puede requerirse una u otra medida (1 m³ = 1000 L).
  String _formatQuantity(SalesState state) {
    final amount = state.amount;
    if (state.productCode == 'GRANEL') {
      return '$amount m³ / ${amount * 1000} L';
    }
    if (state.productCode.startsWith('GARRAFA') ||
        state.productCode.startsWith('TUBO')) {
      return '$amount kg';
    }
    return '$amount m³';
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
          label: 'Tarjeta Destino',
          value: state.cardNumber.isEmpty
              ? '•••• •••• •••• 4321'
              : state.cardNumber,
        ),
        const SizedBox(height: 56),

        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE67E22),
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
