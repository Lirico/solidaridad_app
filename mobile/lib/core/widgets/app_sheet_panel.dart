import 'package:flutter/material.dart';

/// Panel blanco de contenido de las pantallas operativas (patrón estándar).
///
/// A diferencia de las tarjetas flotantes sobre fondo gris, el panel:
/// - ocupa el 100% del ancho de la pantalla;
/// - arranca [topGap] dp por debajo de la cabecera, dejando ver el fondo
///   naranja (igual que la cabecera) en la franja y en la zona que recorta
///   el radio superior, de modo que la cabecera "rellena" la curvatura;
/// - termina pegado al borde superior de la barra inferior (el `Scaffold`
///   reserva el espacio de `AppBottomNavBar`, por eso el panel se apoya
///   exactamente sobre el menú).
class AppSheetPanel extends StatelessWidget {
  /// Radio de las esquinas superiores del panel.
  static const double topRadius = 24;

  /// Franja naranja entre la cabecera y el inicio del panel.
  static const double topGap = 10;

  final Widget child;

  const AppSheetPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSheetPanel.topGap),
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSheetPanel.topRadius),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
