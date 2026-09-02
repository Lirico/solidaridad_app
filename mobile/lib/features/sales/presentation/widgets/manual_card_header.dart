import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo_image.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';

class ManualCardHeader extends StatelessWidget implements PreferredSizeWidget {
  const ManualCardHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryOrange,
      elevation: 0,
      // Logo de la empresa al inicio de la cabecera.
      leadingWidth: 68,
      leading: const Center(child: BrandLogoImage(height: 34)),
      titleSpacing: 0,
      title: const Text(
        'Ingreso Manual',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: const [UserMenuButton(), SizedBox(width: 8)],
    );
  }
}
