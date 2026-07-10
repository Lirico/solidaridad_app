import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado para obtener la lista de operaciones actualizada
    final history = context.watch<SalesCubit>().state.history;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- CABECERA AZUL ---
            Container(
              width: double.infinity,
              height: 180,
              color: const Color(0xFF1A4F9C),
              padding: const EdgeInsets.only(top: 60, left: 16, right: 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Historial de Ventas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- LISTADO FLOTANTE ---
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: history.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: history.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final op = history[index];
                              return _buildHistoryItem(op);
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'Sin operaciones hoy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Las transacciones aprobadas o rechazadas figurarán en este listado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(OperationModel op) {
    final statusColor = op.isSuccess
        ? const Color(0xFF2ECC71)
        : const Color(0xFFE74C3C);
    final statusText = op.isSuccess ? 'APROBADA' : 'RECHAZADA';

    // Formateo rápido de hora de la terminal
    final String timeStr =
        '${op.date.hour.toString().padLeft(2, '0')}:${op.date.minute.toString().padLeft(2, '0')} hs';

    return Row(
      children: [
        // Indicador visual izquierdo
        Container(
          width: 6,
          height: 45,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),

        // Datos principales de la operación
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${op.currency} ${op.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'm³',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${op.id} • ${op.cardNumber}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Estado y Hora alineados a la derecha
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ],
    );
  }
}
