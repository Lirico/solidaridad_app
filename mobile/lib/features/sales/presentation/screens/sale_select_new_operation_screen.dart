import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../widgets/select_new_operation_content.dart';

class SelectNewOperationScreen extends StatelessWidget {
  const SelectNewOperationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Nueva Operación',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: SelectNewOperationContent(
          onCardTap: () =>
              Navigator.pushNamed(context, AppRoutes.saleWaitingForCard),
          onManualCardTap: () =>
              Navigator.pushNamed(context, AppRoutes.saleManualCard),
        ),
      ),
    );
  }
}
