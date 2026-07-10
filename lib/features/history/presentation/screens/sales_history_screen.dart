import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../sales/presentation/cubit/sales_cubit.dart';
import '../../../sales/presentation/cubit/sales_state.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: const Color(0xFF0D47A1), // Azul corporativo
      ),
      body: BlocBuilder<SalesCubit, SalesState>(
        builder: (context, state) {
          final history = state.history;

          if (history.isEmpty) {
            return const Center(
              child: Text(
                'No hay transacciones registradas hoy.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final operation = history[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    operation.isSuccess ? Icons.check_circle : Icons.error,
                    color: operation.isSuccess ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  title: Text(
                    '${operation.currency} ${operation.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${operation.cardNumber} \n${operation.id}'),
                  trailing: Text(
                    '${operation.date.hour.toString().padLeft(2, '0')}:${operation.date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // TODO: Mañana conectamos acá la pantalla del Detalle del Comprobante
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
