import 'package:flutter/material.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';

/// Botón "más" que abre un desplegable blanco con las opciones secundarias.
///
/// Vive en la barra inferior compartida ([AppBottomNavBar]), por eso abre el
/// popup superpuesto al botón ([PopupMenuPosition.over]) para que no se salga
/// de pantalla al estar anclado en el borde inferior.
///
/// Ítems actuales:
/// - **Consultar saldo** y **Cerrar Lote**: deshabilitados hasta que el cliente
///   defina el contrato/backend (no hacen nada por ahora).
/// - **Historial de ventas**: navega al listado.
///
/// El cambio de contraseña NO vive acá: es del menú del ícono de usuario
/// ([UserMenuButton]).
class HeaderMenuButton extends StatelessWidget {
  /// Color del ícono. Blanco sobre cabeceras naranjas; oscuro sobre fondos
  /// claros (barra inferior).
  final Color iconColor;

  /// Permite deshabilitar el menú completo (p. ej. pantallas sin sesión).
  final bool enabled;

  const HeaderMenuButton({
    super.key,
    this.iconColor = Colors.white,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      icon: Icon(Icons.more_horiz, color: iconColor, size: 28),
      tooltip: 'Más opciones',
      position: PopupMenuPosition.over,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: (value) {
        switch (value) {
          case 'salesHistory':
            Navigator.pushNamed(context, AppRoutes.salesHistory);
            break;
          // 'balanceInquiry' y 'closeBatch' están deshabilitados: no navegan.
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          value: 'balanceInquiry',
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.iconGrey,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Consultar saldo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.iconGrey),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          enabled: false,
          value: 'closeBatch',
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.iconGrey, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cerrar Lote',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.iconGrey),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'salesHistory',
          child: Row(
            children: [
              Icon(Icons.history, color: AppColors.iconGrey, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Historial de ventas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
