import 'package:flutter/material.dart';

import '../../../../core/formatters/quantity_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/batch_close_model.dart';

/// Contenido de la pantalla de Cierre de Lote (UI pura).
///
/// Muestra el resumen del lote actual y el botón CERRAR LOTE. No conoce el
/// cubit: recibe el resumen ya calculado y avisa con [onCloseBatch], igual
/// criterio que `BalanceStatusContent`.
///
/// Layout: el resumen puede crecer (una fila por producto), así que la lista
/// scrollea y el botón queda fijo abajo, siempre visible y sin desbordar en
/// 360×720dp.
class BatchCloseContent extends StatelessWidget {
  final BatchSummary summary;
  final VoidCallback onCloseBatch;

  const BatchCloseContent({
    super.key,
    required this.summary,
    required this.onCloseBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoteHeader(batchNumber: summary.batchNumber),
                const SizedBox(height: 20),
                const _SectionTitle(text: 'Resumen de Ventas'),
                const SizedBox(height: 10),
                _SummaryCard(summary: summary),
                if (summary.isPartial) ...[
                  const SizedBox(height: 12),
                  const _PartialWarning(),
                ],
                const SizedBox(height: 20),
                const _SectionTitle(text: 'Ventas por Producto'),
                const SizedBox(height: 10),
                const _ProductsHeaderRow(),
                if (summary.products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hay ventas registradas en el lote.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                else
                  for (final BatchProductItem item in summary.products)
                    _ProductRow(item: item),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onCloseBatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
              ),
              child: const Text(
                'CERRAR LOTE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Lote Actual" + pill verde con el número de lote.
class _LoteHeader extends StatelessWidget {
  final String batchNumber;

  const _LoteHeader({required this.batchNumber});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Lote Actual',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.successSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            batchNumber,
            style: const TextStyle(
              color: AppColors.successStrong,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Título de sección del panel ("Resumen de Ventas", "Ventas por Producto").
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5A6A85),
      ),
    );
  }
}

/// Card "Resumen de Ventas": cantidad de ventas y total del lote.
class _SummaryCard extends StatelessWidget {
  final BatchSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Cantidad de Ventas',
            value: '${summary.salesCount}',
            valueColor: AppColors.successGreen,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Total de Ventas',
            value: '${formatQuantityEs(summary.totalKg)} kg',
            valueColor: AppColors.successStrong,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// Aviso cuando el resumen pudo quedar incompleto (se agotó el tope de páginas).
class _PartialWarning extends StatelessWidget {
  const _PartialWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.warningOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'El resumen puede estar incompleto: hay demasiadas ventas para listarlas todas.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8D6E00)),
            ),
          ),
        ],
      ),
    );
  }
}

const double _qtyColumnWidth = 60;
const double _kgColumnWidth = 78;

/// Cabecera de la tabla de productos (mismos anchos que [_ProductRow]).
class _ProductsHeaderRow extends StatelessWidget {
  const _ProductsHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text('Producto', style: _headerStyle)),
          SizedBox(
            width: _qtyColumnWidth,
            child: Text(
              'Cantidad',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _headerStyle,
            ),
          ),
          SizedBox(
            width: _kgColumnWidth,
            child: Text(
              'Kg',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _headerStyle,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: AppColors.textSecondary,
);

/// Fila de "Ventas por Producto": producto, cantidad vendida y kg.
class _ProductRow extends StatelessWidget {
  final BatchProductItem item;

  const _ProductRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.propane_tank_outlined,
            size: 22,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: _qtyColumnWidth,
            child: Text(
              formatQuantityEs(item.quantity),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: _kgColumnWidth,
            child: Text(
              '${formatQuantityEs(item.kg)} Kg',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
