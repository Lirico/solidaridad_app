import 'package:flutter/material.dart';

import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import 'header_menu_button.dart';

/// Barra de navegación inferior compartida por las pantallas interactivas.
///
/// Layout fijo (tal como el mockup "Screen 1"):
/// ← atrás (izquierda) | botón VENTA (centro) | ⋯ más (derecha).
///
/// El botón central **VENTA** navega a la pantalla de selección de producto y
/// cantidad ([AppRoutes.saleForm]) y resetea la pila para empezar una venta
/// limpia desde cualquier punto.
class AppBottomNavBar extends StatelessWidget {
  /// Callback custom para la flecha "atrás". Por defecto hace `maybePop`.
  final VoidCallback? onBack;

  /// Oculta la flecha "atrás" en pantallas finales/transitorias donde no
  /// corresponde volver al paso anterior (procesando, resultado, etc.).
  final bool hideBack;

  /// Deshabilita VENTA y ⋯ en pantallas sin sesión iniciada (Login/Registro).
  final bool enabled;

  const AppBottomNavBar({
    super.key,
    this.onBack,
    this.hideBack = false,
    this.enabled = true,
  });

  void _openSale(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.saleForm,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color disabledColor = AppColors.inputPlaceholder;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: const Border(
          top: BorderSide(color: AppColors.inputBorderEnabled),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBlack05,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // ← Volver
              SizedBox(
                width: 72,
                child: hideBack
                    ? null
                    : Center(
                        child: IconButton(
                          tooltip: 'Volver',
                          icon: Icon(
                            Icons.arrow_back,
                            color: enabled
                                ? AppColors.textPrimary
                                : disabledColor,
                            size: 28,
                          ),
                          onPressed: enabled
                              ? onBack ?? () => Navigator.maybePop(context)
                              : null,
                        ),
                      ),
              ),

              // VENTA (centro)
              Expanded(
                child: Center(
                  child: _VentaButton(
                    enabled: enabled,
                    onTap: () => _openSale(context),
                  ),
                ),
              ),

              // ⋯ Más
              SizedBox(
                width: 72,
                child: Center(
                  child: HeaderMenuButton(
                    iconColor: enabled ? AppColors.textPrimary : disabledColor,
                    enabled: enabled,
                    showLabel: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular central de la barra inferior: carrito + "VENTA".
///
/// Mide 58dp para entrar completo en la barra de 64dp sin agrandarla ni
/// sobresalir del menú. El ícono y el texto se ajustan (20px/10px) para que
/// ambos quepan dentro del círculo.
class _VentaButton extends StatelessWidget {
  static const double _size = 58;

  final bool enabled;
  final VoidCallback onTap;

  const _VentaButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Colores de marca fijos: fondo naranja de cabeceras y contenido blanco
    // (el blanco del fondo del menú). Deshabilitado solo queda inerte (onTap
    // null) pero conserva la identidad visual.
    return SizedBox(
      width: _size,
      height: _size,
      child: Material(
        color: AppColors.primaryOrange,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: AppColors.shadowLight,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart, size: 20, color: Colors.white),
              SizedBox(height: 1),
              Text(
                'VENTA',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
