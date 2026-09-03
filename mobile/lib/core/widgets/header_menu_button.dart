import 'package:flutter/material.dart';

import 'more_menu.dart';

/// Botón "⋯ Más" de la barra inferior.
///
/// Vive en la barra inferior compartida ([AppBottomNavBar]). Al tocarlo abre
/// [MoreMenu]: un panel que ocupa el área del cajón blanco de la pantalla
/// (ancho completo, radio superior 24, pegado a la barra inferior).
///
/// Ítems del panel:
/// - **Consultar saldo** y **Cerrar Lote**: deshabilitados hasta que el cliente
///   defina el contrato/backend (no hacen nada por ahora).
/// - **Historial de ventas**: navega al listado.
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
            onTap: enabled
                ? () {
                    // El botón llena los 64dp del menú: su borde superior en
                    // coordenadas globales es el arranque de la barra inferior.
                    final RenderBox box =
                        context.findRenderObject()! as RenderBox;
                    final double navTop = box.localToGlobal(Offset.zero).dy;
                    MoreMenu.show(context, navTop: navTop);
                  }
                : null,
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
