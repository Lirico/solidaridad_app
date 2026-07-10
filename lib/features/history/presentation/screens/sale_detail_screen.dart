import 'package:flutter/material.dart';
import '../../data/models/operation_model.dart';

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Recibimos la operación por los argumentos de la ruta nativa
    final operation =
        ModalRoute.of(context)!.settings.arguments as OperationModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Comprobante'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
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
                        operation.isSuccess
                            ? 'VENTA EXITOSA'
                            : 'VENTA RECHAZADA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: operation.isSuccess
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${operation.currency} ${operation.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ), // 👑 CORREGIDO: bold a secas
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
            ),
          ),
        ),
      ),
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
