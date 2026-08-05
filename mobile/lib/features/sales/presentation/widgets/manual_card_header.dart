import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ManualCardHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBackPressed;

  const ManualCardHeader({super.key, this.onBackPressed});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryOrange,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPressed,
      ),
      title: const Text(
        'Ingreso Manual',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}
