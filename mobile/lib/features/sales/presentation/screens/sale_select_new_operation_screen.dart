import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../widgets/select_new_operation_content.dart';
import '../widgets/select_new_operation_header.dart';

class SelectNewOperationScreen extends StatelessWidget {
  const SelectNewOperationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const SelectNewOperationHeader(),
      bottomNavigationBar: const AppBottomNavBar(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SelectNewOperationContent(
                onCardTap: () =>
                    Navigator.pushNamed(context, AppRoutes.saleWaitingForCard),
                onManualCardTap: () =>
                    Navigator.pushNamed(context, AppRoutes.saleManualCard),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
