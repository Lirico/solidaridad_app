import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo_image.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';

class SalesHistoryHeader extends StatelessWidget {
  const SalesHistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 16),
      child: Row(
        children: [
          // Logo de la empresa, en la misma línea que el ícono de usuario.
          const BrandLogoImage(height: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Historial de Ventas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const UserMenuButton(),
        ],
      ),
    );
  }
}
