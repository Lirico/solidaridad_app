import 'package:flutter/material.dart';
import '../../../sales/domain/sale_model.dart';

class SaleDetailTicket extends StatelessWidget {
  final OperationModel operation;

  const SaleDetailTicket({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                operation.isSuccess ? Icons.check_circle : Icons.cancel,
                color: operation.isSuccess ? Colors.green : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                operation.isSuccess ? 'VENTA EXITOSA' : 'VENTA RECHAZADA',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: operation.isSuccess ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${operation.currency} ${operation.amount.toStringAsFixed(2)}',
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
