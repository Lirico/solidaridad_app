import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo_image.dart';

/// Cabecera POS compartida (AppBar naranja compacto de 64dp).
///
/// Reemplaza a los headers custom de alto fijo (180dp) que desbordaban en
/// pantallas chicas: el logo de la empresa se muestra como `leading` en la
/// misma línea que el título y [actions] (p. ej. el [UserMenuButton] del
/// feature auth). El propio [AppBar] absorbe el espacio de la barra de
/// estado, por lo que las pantallas ya no necesitan `SafeArea(top: false)`.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.actions = const []});

  /// Título de la pantalla (blanco, bold, 20dp).
  final String title;

  /// Acciones a la derecha del título. El botón de usuario se inyecta desde
  /// cada feature para no acoplar `core` con un feature concreto.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 68,
      leading: const Center(child: BrandLogoImage(height: 34)),
      titleSpacing: 0,
      backgroundColor: AppColors.primaryOrange,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: actions,
    );
  }
}
