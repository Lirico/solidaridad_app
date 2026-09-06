import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../cubit/sales_cubit.dart';
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
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Confirmar Operación',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SaleReviewContent(
            state: salesState,
            onConfirm: () => _onConfirmPayment(context),
          ),
        ),
      ),
    );
  }
}
