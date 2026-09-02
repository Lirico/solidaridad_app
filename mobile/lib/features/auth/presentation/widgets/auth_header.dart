import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brand_logo_image.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.only(top: 52, left: 24, right: 24),
      child: Stack(
        children: [
          // Logo de la empresa en la línea superior de la cabecera.
          const Positioned(
            top: 0,
            left: 0,
            child: BrandLogoImage(height: 40),
          ),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_gas_station, color: Colors.orange, size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('GAS', style: AppTextStyles.headerTitle),
                    Text('TERMINAL', style: AppTextStyles.headerSubtitle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
