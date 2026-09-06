import 'package:flutter/material.dart';

import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import 'app_sheet_panel.dart';

/// Menú "⋯ Más" ampliado.
///
/// En lugar del `PopupMenuButton` chico anclado al botón, el menú se abre como
/// un overlay que replica la geometría del cajón blanco ([AppSheetPanel]):
/// ocupa el 100% del ancho, arranca [AppSheetPanel.topGap] dp debajo de la
/// cabecera (quedando visibles la cabecera naranja y la franja que "rellena"
/// la curvatura) y termina pegado al borde superior de la barra inferior.
///
/// El overlay es transparente: la cabecera y la barra inferior quedan visibles
/// detrás y cualquier toque fuera del panel lo cierra (`barrierDismissible`).
class MoreMenu {
  const MoreMenu._();

  /// Altura de `AppHeader.preferredSize` (cabecera compacta 64dp).
  static const double _appHeaderHeight = 64;

  /// El borde superior de la barra inferior no se calcula: se mide desde el
  /// botón al abrir ([MoreMenu.show]) porque la barra consume su propio inset.

  /// Abre el panel de más opciones sobre el área del cajón blanco.
  ///
  /// [navTop] es el borde superior de la barra inferior en coordenadas
  /// globales; se mide desde el botón (que llena los 64dp del menú) para que
  /// el panel termine exactamente donde arranca la barra.
  static Future<void> show(
    BuildContext context, {
    required double navTop,
  }) async {
    final String? selection = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar menú de más opciones',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (dialogContext, animation, secondary, child) {
        // Aparece deslizándose apenas desde arriba y con fundido, sobre el
        // mismo lugar que ocuparía el cajón blanco.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        // El borde superior del cajón sale del padding real del view + los
        // 64dp de la cabecera; el inferior llega medido desde el botón
        // ([navTop]), porque la barra consume su propio inset vía SafeArea.
        final MediaQueryData viewData = MediaQueryData.fromView(
          View.of(dialogContext),
        );
        final double bodyTop = viewData.padding.top + _appHeaderHeight;
        final double sheetTop = bodyTop + AppSheetPanel.topGap;
        final double sheetHeight = navTop - sheetTop;

        return _MoreMenuOverlay(
          top: sheetTop,
          height: sheetHeight,
          onClose: () => Navigator.pop(dialogContext),
          onHistorySelected: () =>
              Navigator.pop(dialogContext, AppRoutes.salesHistory),
        );
      },
    );

    if (selection == AppRoutes.salesHistory && context.mounted) {
      Navigator.pushNamed(context, AppRoutes.salesHistory);
    }
  }
}

/// Coloca el panel blanco exactamente sobre el área del cajón de la pantalla.
class _MoreMenuOverlay extends StatelessWidget {
  final double top;
  final double height;
  final VoidCallback onClose;
  final VoidCallback onHistorySelected;

  const _MoreMenuOverlay({
    required this.top,
    required this.height,
    required this.onClose,
    required this.onHistorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: _MoreMenuSheet(
            onClose: onClose,
            onHistorySelected: onHistorySelected,
          ),
        ),
      ],
    );
  }
}

/// Panel blanco con radio superior 24 y el listado de opciones.
class _MoreMenuSheet extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onHistorySelected;

  const _MoreMenuSheet({
    required this.onClose,
    required this.onHistorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('moreMenuSheet'),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSheetPanel.topRadius),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MoreMenuHeader(onClose: onClose),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MoreMenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Consultar saldo',
                      subtitle: 'Próximamente',
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    const _MoreMenuTile(
                      icon: Icons.lock_outline,
                      title: 'Cerrar Lote',
                      subtitle: 'Próximamente',
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    _MoreMenuTile(
                      icon: Icons.history,
                      title: 'Historial de ventas',
                      subtitle: 'Ver operaciones realizadas',
                      enabled: true,
                      onTap: onHistorySelected,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primaryOrange,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CERRAR',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'También podés cerrar tocando fuera del menú.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado del panel: título + botón de cierre.
class _MoreMenuHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _MoreMenuHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 12, 10),
      child: Row(
        children: [
          const Icon(
            Icons.more_horiz,
            size: 28,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(width: 8),
          const Text(
            'Más opciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cerrar menú',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de opción grande (tipo tile) dentro del panel de más opciones.
class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = enabled
        ? AppColors.primaryOrange
        : AppColors.iconGrey;
    final Color textColor = enabled
        ? AppColors.textPrimary
        : AppColors.iconGrey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFFFFF3ED)
                      : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 28, color: baseColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? Colors.grey.shade600 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
