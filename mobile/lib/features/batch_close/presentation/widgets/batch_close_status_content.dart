import 'package:flutter/material.dart';

import '../../../../core/formatters/quantity_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/batch_close_model.dart';

/// Contenido del resultado del cierre de lote (UI pura).
class BatchCloseStatusContent extends StatelessWidget {
  /// `true` si el lote se cerró: se muestra el comprobante en pantalla.
  final bool isClosed;

  /// Resumen del lote cerrado (presente cuando [isClosed]).
  final BatchSummary? summary;

  /// Mensaje a mostrar cuando el cierre no se pudo completar.
  final String message;

  final VoidCallback onFinalize;

  const BatchCloseStatusContent({
    super.key,
    required this.isClosed,
    required this.message,
    required this.onFinalize,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (isClosed && summary != null) {
      return _buildClosed(context, summary!);
    }
    return _buildError(context);
  }

  Widget _buildClosed(BuildContext context, BatchSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: AppColors.successGreen,
        ),
        const SizedBox(height: 12),
        const Text(
          '¡Lote Cerrado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.successStrong,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'El lote Nº ${summary.batchNumber} se cerró en el terminal.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            children: [
              _StatusRow(label: 'Nº de Lote', value: summary.batchNumber),
              const Divider(height: 1),
              _StatusRow(
                label: 'Cantidad de Ventas',
                value: '${summary.salesCount}',
              ),
              const Divider(height: 1),
              _StatusRow(
                label: 'Total de Ventas',
                value: '${formatQuantityEs(summary.totalKg)} kg',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pendiente el envío del cierre al procesador.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Spacer(),
        _FinalizeButton(onFinalize: onFinalize),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
        const SizedBox(height: 12),
        const Text(
          'No se pudo cerrar el lote',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Spacer(),
        _FinalizeButton(onFinalize: onFinalize),
      ],
    );
  }
}

/// Botón FINALIZAR del resultado (mismo alto/estilo que el resto del flujo).
class _FinalizeButton extends StatelessWidget {
  final VoidCallback onFinalize;

  const _FinalizeButton({required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onFinalize,
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
          'FINALIZAR',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
