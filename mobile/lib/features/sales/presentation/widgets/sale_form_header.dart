import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_menu_button.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';

class SaleFormHeader extends StatelessWidget {
  const SaleFormHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Nueva Operación',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              const HeaderMenuButton(),
              const SizedBox(width: 8),
              const UserMenuButton(),
            ],
          ),
        ],
      ),
    );
  }
}
