import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/sales_cubit.dart';
import '../widgets/sale_review_header.dart';
import '../widgets/sale_review_content.dart';

class SaleReviewScreen extends StatelessWidget {
  const SaleReviewScreen({super.key});

  void _onConfirmPayment(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final token = authState is AuthSuccess ? authState.user!.token : '';

    // Kick off the ISO message sending
    context.read<SalesCubit>().sendIsoMessage(token: token);

    // Navigate to the full-screen processing page
    Navigator.pushNamed(context, AppRoutes.saleProcessing);
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
              onBackPressed: () => Navigator.pop(context),
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
                    child: SaleReviewContent(
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
