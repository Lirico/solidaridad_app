import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../cubit/balance_cubit.dart';
import '../widgets/balance_review_content.dart';

class BalanceReviewScreen extends StatelessWidget {
  const BalanceReviewScreen({super.key});

  void _onConfirm(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final token = authState is AuthSuccess ? authState.user!.token : '';

    context.read<BalanceCubit>().checkBalance(token: token);
    Navigator.pushNamed(context, AppRoutes.balanceProcessing);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Confirmar Consulta',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BalanceReviewContent(
            cardNumber: state.cardNumber,
            onConfirm: () => _onConfirm(context),
          ),
        ),
      ),
    );
  }
}
