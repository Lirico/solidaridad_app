import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/sale_model.dart';

class SaleStatusContent extends StatelessWidget {
  final PaymentResult result;
  final Color statusColor;
  final IconData statusIcon;
  final String statusTitle;
  final String statusSubtitle;
  final VoidCallback onFinalize;

  const SaleStatusContent({
    super.key,
    required this.result,
    required this.statusColor,
    required this.statusIcon,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),

        Icon(statusIcon, size: 100, color: statusColor),
        const SizedBox(height: 24),

        Text(
          statusTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          statusSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            children: [
              _buildTicketRow('ID de terminal', 'TERM-00432'),
              const Divider(height: 20),
              _buildTicketRow(
                'Nro. Operación',
                result == PaymentResult.approved ? 'OP-987452' : '---',
              ),
              const Divider(height: 20),
              _buildTicketRow('Código de respuesta', _responseCode(result)),
            ],
          ),
        ),

        const Spacer(),

        ElevatedButton(
          onPressed: onFinalize,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            'FINALIZAR',
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

  String _responseCode(PaymentResult result) {
    switch (result) {
      case PaymentResult.approved:
        return '00 (Aprobado)';
      case PaymentResult.declined:
        return '51 (Fondos insuficientes)';
      case PaymentResult.connectionError:
        return '99 (Tiempo agotado)';
      case PaymentResult.voided:
        return '00 (ANULADA)';
    }
  }

  Widget _buildTicketRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
