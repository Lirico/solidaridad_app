import 'package:flutter/material.dart';
import '../../../../core/formatters/amount_formatter.dart';
import '../../../sales/domain/sale_model.dart';

class SaleDetailTicket extends StatelessWidget {
  final OperationModel operation;

  const SaleDetailTicket({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;

    switch (operation.result) {
      case PaymentResult.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'VENTA EXITOSA';
      case PaymentResult.declined:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTitle = 'VENTA RECHAZADA';
      case PaymentResult.connectionError:
        statusColor = Colors.orange;
        statusIcon = Icons.wifi_off;
        statusTitle = 'ERROR DE CONEXIÓN';
      case PaymentResult.voided:
        statusColor = Colors.grey;
        statusIcon = Icons.undo;
        statusTitle = 'VENTA ANULADA';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 64),
              const SizedBox(height: 12),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${operation.productLabel} — ${formatAmount(operation.amount)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 40, thickness: 1),
        _buildTicketRow('ID Operación:', operation.id),
        _buildTicketRow(
          'Fecha:',
          '${operation.date.day}/${operation.date.month}/${operation.date.year}',
        ),
        _buildTicketRow(
          'Hora:',
          '${operation.date.hour.toString().padLeft(2, '0')}:${operation.date.minute.toString().padLeft(2, '0')} hs',
        ),
        _buildTicketRow('Tarjeta (PAN):', operation.cardNumber),
        if (operation.userMessage != null &&
            operation.userMessage!.isNotEmpty) ...[
          const Divider(height: 24, thickness: 1),
          _buildTicketRow('Mensaje:', operation.userMessage!),
        ],
        const Divider(height: 40, thickness: 1),
        const Center(
          child: Text(
            'GAS Terminal - Sistema de Distribución',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
