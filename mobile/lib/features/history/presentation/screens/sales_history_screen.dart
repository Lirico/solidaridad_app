import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/cubit/sales_cubit.dart';
import '../../../sales/presentation/cubit/sales_state.dart';
import '../widgets/sales_history_header.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SalesHistoryHeader(),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildBody(context),
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

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<SalesCubit, SalesState>(
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
                  operation.result == PaymentResult.approved
                      ? Icons.check_circle
                      : operation.result == PaymentResult.connectionError
                      ? Icons.wifi_off
                      : Icons.error,
                  color: operation.result == PaymentResult.approved
                      ? Colors.green
                      : operation.result == PaymentResult.connectionError
                      ? Colors.orange
                      : Colors.red,
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
                  Navigator.pushNamed(
                    context,
                    AppRoutes.saleDetail,
                    arguments: operation,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
