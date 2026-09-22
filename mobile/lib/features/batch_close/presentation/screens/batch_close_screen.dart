import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../domain/batch_close_model.dart';
import '../widgets/batch_close_content.dart';

/// Callback inerte del prototipo.
///
/// El botón CERRAR LOTE se ve habilitado (como el mockup) pero todavía no hace
/// nada: falta el resumen real desde la API y el contrato del cierre contra el
/// procesador. Ver `docs/gaps.md` (G-P2-10).
void _onCloseBatchTodo() {}

/// Cierre de Lote — prototipo visual.
///
/// Muestra la pantalla del mockup del cliente con **datos de ejemplo** (no
/// salen de ninguna venta real). El resumen real y el cierre efectivo se
/// integran en un trabajo posterior: ver `docs/gaps.md` (G-P2-10).
class BatchCloseScreen extends StatelessWidget {
  const BatchCloseScreen({super.key});

  /// Valores del mockup del cliente, cargados a mano.
  ///
  /// El total en kg es la suma de la columna "Kg" de la tabla. El mockup
  /// mostraba además un importe en pesos (`$ 125.750,00`) que no se puede
  /// calcular: la API no expone el precio por producto.
  static const BatchSummary _demoSummary = BatchSummary(
    batchNumber: '000123',
    salesCount: 45,
    totalKg: 2055,
    products: <BatchProductItem>[
      BatchProductItem(
        productCode: 'GARRAFA_10',
        label: 'Garrafa 10 kg',
        quantity: 15,
        kg: 150,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GARRAFA_15',
        label: 'Garrafa 15 kg',
        quantity: 10,
        kg: 150,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GARRAFA_30',
        label: 'Garrafa 30 kg',
        quantity: 8,
        kg: 240,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'TUBO_45',
        label: 'Tubo 45 kg',
        quantity: 7,
        kg: 315,
        unitLabel: 'unidades',
      ),
      BatchProductItem(
        productCode: 'GRANEL',
        label: 'Granel',
        quantity: 1200,
        kg: 1200,
        unitLabel: 'm³',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Cierre de Lote',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: const AppSheetPanel(
        child: BatchCloseContent(
          summary: _demoSummary,
          onCloseBatch: _onCloseBatchTodo,
        ),
      ),
    );
  }
}
