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
                  child: SizedBox(
                    width: 190,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: enabled ? () => _openSale(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: AppColors.textWhite,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 24),
                      label: const Text(
                        'VENTA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ⋯ Más
              SizedBox(
                width: 72,
                child: Center(
                  child: HeaderMenuButton(
                    iconColor: enabled
                        ? AppColors.textPrimary
                        : disabledColor,
                    enabled: enabled,
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
