import 'package:flutter/material.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';

class HeaderMenuButton extends StatelessWidget {
  const HeaderMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.white, size: 28),
      tooltip: 'Menú',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: (value) {
        switch (value) {
          case 'changePassword':
            Navigator.pushNamed(context, AppRoutes.changePassword);
            break;
          case 'salesHistory':
            Navigator.pushNamed(context, AppRoutes.salesHistory);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'changePassword',
          child: Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.iconGrey, size: 20),
              SizedBox(width: 12),
              Text('Cambiar Contraseña'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'salesHistory',
          child: Row(
            children: [
              Icon(Icons.history, color: AppColors.iconGrey, size: 20),
              SizedBox(width: 12),
              Text('Ver historial de ventas'),
            ],
          ),
        ),
      ],
    );
  }
}
