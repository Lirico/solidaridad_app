import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';
import '../widgets/sale_review_widgets.dart';
import '../widgets/sale_review_header.dart';
import '../widgets/sale_review_content.dart';

class SaleReviewScreen extends StatelessWidget {
  const SaleReviewScreen({super.key});

  void _onConfirmPayment(BuildContext context) async {
    final salesCubit = context.read<SalesCubit>();
    await salesCubit.sendIsoMessage();

    if (!context.mounted) return;

    final finalState = salesCubit.state;
    final bool success = finalState is SalesCompleted && finalState.isSuccess;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.saleStatus,
      arguments: success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesState = context.watch<SalesCubit>().state;
    final isProcessing = salesState is SalesProcessing;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SaleReviewHeader(
              title: 'Confirmar Operación',
              onBackPressed: isProcessing ? null : () => Navigator.pop(context),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                    child: isProcessing
                        ? const ProcessingTransactionView()
                        : SaleReviewContent(
                            state: salesState,
                            onConfirm: () => _onConfirmPayment(context),
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
}
