import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class WaitingForCardBottomBar extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const WaitingForCardBottomBar({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: TextButton.icon(
          onPressed: onBackPressed ?? () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primaryOrange,
            size: 20,
          ),
          label: const Text(
            'VOLVER',
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
