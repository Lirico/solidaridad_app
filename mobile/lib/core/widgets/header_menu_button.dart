import 'package:flutter/material.dart';

import '../constants/app_routes.dart';
import 'more_menu.dart';

/// Botón "⋯ Más" de la barra inferior.
///
/// Vive en la barra inferior compartida ([AppBottomNavBar]). Al tocarlo abre
/// [MoreMenu]: un panel que ocupa el área del cajón blanco de la pantalla
/// (ancho completo, radio superior 24, pegado a la barra inferior).
///
/// Ítems del panel:
/// - **Consultar saldo**: navega al flujo de consulta de saldo (captura manual
///   o por banda, resultado con tabla Producto | Cantidad).
/// - **Cerrar Lote**: navega al resumen del lote actual (informativo, sin
///   cierre: ver `docs/gaps.md`, G-P2-10).
/// - **Historial de ventas**: navega al listado.
///
/// La navegación de esas opciones vive acá: [MoreMenu] solo devuelve la
/// `MoreMenuOption` elegida.
///
/// El cambio de contraseña NO vive acá: es del menú del ícono de usuario
/// ([UserMenuButton]).
class HeaderMenuButton extends StatelessWidget {
  /// Color del ícono (y de la etiqueta "Más" cuando [showLabel] es true).
  /// Blanco sobre cabeceras naranjas; oscuro sobre fondos claros (barra inferior).
  final Color iconColor;

  /// Permite deshabilitar el menú completo (p. ej. pantallas sin sesión).
  final bool enabled;

  /// Muestra la palabra "Más" debajo de los tres puntos (barra inferior).
  final bool showLabel;

  const HeaderMenuButton({
    super.key,
    this.iconColor = Colors.white,
    this.enabled = true,
    this.showLabel = false,
  });

  /// Abre el panel "⋯ Más" y navega a la opción elegida.
  ///
  /// [MoreMenu] no navega: devuelve la [MoreMenuOption] y acá se mapea a
  /// [AppRoutes]. El botón llena los 64dp del menú, de modo que su borde
  /// superior en coordenadas globales es también el arranque de la barra
  /// inferior: ese valor es el `navTop` que espera `MoreMenu.show`.
  Future<void> _openMoreMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final double navTop = box.localToGlobal(Offset.zero).dy;

    final MoreMenuOption? option = await MoreMenu.show(context, navTop: navTop);
    if (option == null || !context.mounted) {
      return;
    }

    switch (option) {
      case MoreMenuOption.balance:
        Navigator.pushNamed(context, AppRoutes.balanceCaptureMode);
      case MoreMenuOption.batchClose:
        Navigator.pushNamed(context, AppRoutes.batchClose);
      case MoreMenuOption.salesHistory:
        Navigator.pushNamed(context, AppRoutes.salesHistory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Más opciones',
      child: Tooltip(
        message: 'Más opciones',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => _openMoreMenu(context) : null,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: showLabel ? 64 : 48,
              height: showLabel ? 64 : 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.more_horiz, color: iconColor, size: 28),
                  if (showLabel) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Más',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: iconColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
