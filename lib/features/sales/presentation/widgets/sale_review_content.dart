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
          label: 'Moneda de Cobro',
          value: state.currency,
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.local_gas_station_outlined,
          label: 'Cantidad de Gas',
          value: '${state.amount} m³',
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.credit_card_outlined,
          label: 'Tarjeta Destino',
          value: state.cardNumber.isEmpty
              ? '•••• •••• •••• 4321'
              : state.cardNumber,
        ),
        const Spacer(),

        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE67E22),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            'CONFIRMAR COBRO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
