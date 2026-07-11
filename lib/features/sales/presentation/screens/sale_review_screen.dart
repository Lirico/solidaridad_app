import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';
import '../widgets/sale_review_widgets.dart';
import '../widgets/sale_review_header.dart'; // 👑 NUEVO
import '../widgets/sale_review_content.dart'; // 👑 NUEVO

class SaleReviewScreen extends StatefulWidget {
  const SaleReviewScreen({super.key});

  @override
  State<SaleReviewScreen> createState() => _SaleReviewScreenState();
}

class _SaleReviewScreenState extends State<SaleReviewScreen> {
  bool _isProcessing = false;

  void _onConfirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    final salesCubit = context.read<SalesCubit>();
    await salesCubit.sendIsoMessage();

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    final finalState = salesCubit.state;
    final bool success = finalState is SalesSuccess;

    Navigator.pushReplacementNamed(context, '/sale_status', arguments: success);
  }

  @override
  Widget build(BuildContext context) {
    final salesState = context.watch<SalesCubit>().state;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SaleReviewHeader(
              title: 'Confirmar Operación',
              onBackPressed: _isProcessing
                  ? null
                  : () => Navigator.pop(context),
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
                    child: _isProcessing
                        ? const ProcessingTransactionView()
                        : SaleReviewContent(
                            // 👑 CONTENIDO AISLADO AQUÍ
                            state: salesState,
                            onConfirm: _onConfirmPayment,
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
