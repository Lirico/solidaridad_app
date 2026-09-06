import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brand_logo_image.dart';

class AuthHeader extends StatelessWidget {
  /// Muestra o no el logo.png de la empresa en la esquina superior de la cabecera.
  ///
  /// Login no lo muestra: al no tener fila de ícono de usuario, el logo ocupa
  /// una fila extra y genera desborde vertical en la pantalla.
  final bool showLogo;

  /// Cuando es `true`, el centro de la cabecera muestra `solidaridad_logo.png`
  /// en lugar del bloque "GAS TERMINAL". Lo usa Login.
  final bool useSolidaridadLogo;

  const AuthHeader({
    super.key,
    this.showLogo = true,
    this.useSolidaridadLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.primaryOrange,
      // En Login (logo SOLIDARIDAD centrado) se reduce el padding lateral para
      // que el logo agrandado (~2x) entre sin desbordar en 360dp.
      padding: EdgeInsets.only(
        top: 52,
        left: useSolidaridadLogo ? 16 : 24,
        right: useSolidaridadLogo ? 16 : 24,
      ),
      child: Stack(
        children: [
          // Logo de la empresa en la línea superior de la cabecera.
          if (showLogo)
            const Positioned(
              top: 0,
              left: 0,
              child: BrandLogoImage(height: 40),
            ),
          Center(
            child: useSolidaridadLogo
                ? const Image(
                    image: AssetImage('assets/solidaridad_logo.png'),
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.contain,
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_gas_station,
                        color: Colors.orange,
                        size: 40,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('GAS', style: AppTextStyles.headerTitle),
                          Text('TERMINAL', style: AppTextStyles.headerSubtitle),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
