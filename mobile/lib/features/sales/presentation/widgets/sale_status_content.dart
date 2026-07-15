import 'package:flutter/material.dart';

class SaleStatusContent extends StatelessWidget {
  final bool isSuccess;
  final Color statusColor;
  final IconData statusIcon;
  final String statusTitle;
  final String statusSubtitle;
  final VoidCallback onFinalize;

  const SaleStatusContent({
    super.key,
    required this.isSuccess,
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
              _buildTicketRow('Terminal ID', 'TERM-00432'),
              const Divider(height: 20),
              _buildTicketRow(
                'Nro. Operación',
                isSuccess ? 'OP-987452' : '---',
              ),
              const Divider(height: 20),
              _buildTicketRow(
                'Código Respuesta',
                isSuccess ? '00 (OK)' : '51 (Fondos Insuf.)',
              ),
            ],
          ),
        ),

        const Spacer(),

        ElevatedButton(
          onPressed: onFinalize,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A4F9C),
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
