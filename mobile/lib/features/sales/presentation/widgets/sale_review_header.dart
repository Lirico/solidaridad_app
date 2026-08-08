import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_menu_button.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';

class SaleReviewHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const SaleReviewHeader({super.key, required this.title, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 16),
      child: Row(
        children: [
          if (onBackPressed != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBackPressed,
            )
          else
            const SizedBox(width: 48),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const HeaderMenuButton(),
          const SizedBox(width: 8),
          const UserMenuButton(),
        ],
      ),
    );
  }
}
