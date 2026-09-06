import 'package:flutter/material.dart';

/// Muestra el logo blanco de la empresa (`assets/logo.png`).
///
/// El asset tiene fondo transparente y el contenido en blanco, pensado para
/// ubicarse sobre cabeceras naranjas ([AppColors.primaryOrange]). La altura
/// por defecto está pensada para la línea superior de los headers.
class BrandLogoImage extends StatelessWidget {
  final double height;

  const BrandLogoImage({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      height: height,
      fit: BoxFit.contain,
      // Evita romper el layout si el asset no está declarado en pubspec.
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
