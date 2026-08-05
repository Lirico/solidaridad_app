import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_menu_button.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';

class SelectNewOperationHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const SelectNewOperationHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryOrange,
      elevation: 0,
      title: const Text(
        'Nueva Operación',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: const [HeaderMenuButton(), SizedBox(width: 8), UserMenuButton()],
    );
  }
}
