import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppSpacing.headerHeight,
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.only(
        top: AppSpacing.headerTopPadding,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_gas_station, color: Colors.orange, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('GAS', style: AppTextStyles.headerTitle),
              Text('TERMINAL', style: AppTextStyles.headerSubtitle),
            ],
          ),
        ],
      ),
    );
  }
}
