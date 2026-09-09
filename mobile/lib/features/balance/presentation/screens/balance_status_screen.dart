import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../domain/balance_model.dart';
import '../cubit/balance_cubit.dart';
import '../cubit/balance_state.dart';
import '../widgets/balance_status_content.dart';

class BalanceStatusScreen extends StatelessWidget {
  const BalanceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceCubit>().state;
    final BalanceResult result = state is BalanceCompleted
        ? state.result
        : const BalanceResult(
            status: BalanceStatus.declined,
            balances: [],
            message: 'No se pudo consultar el saldo',
          );

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Resultado de la Consulta',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(hideBack: true),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BalanceStatusContent(
            result: result,
            onFinalize: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.saleForm,
                (route) => false,
              );
            },
          ),
        ),
      ),
    );
  }
}
