import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../cubit/batch_close_cubit.dart';
import '../cubit/batch_close_state.dart';
import '../widgets/batch_close_status_content.dart';

/// Resultado del cierre de lote (pantalla final: sin flecha atrás útil).
class BatchCloseStatusScreen extends StatelessWidget {
  const BatchCloseStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BatchCloseState state = context.watch<BatchCloseCubit>().state;
    final bool isClosed = state is BatchCloseClosed;
    final String message = state is BatchCloseFailed
        ? state.message
        : 'El lote no se cerró. Vuelva a intentarlo desde Cierre de Lote.';

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Resultado del Cierre',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(hideBack: true),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BatchCloseStatusContent(
            isClosed: isClosed,
            summary: state is BatchCloseClosed ? state.summary : null,
            message: message,
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
