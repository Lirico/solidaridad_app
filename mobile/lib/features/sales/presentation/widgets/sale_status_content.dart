import 'package:flutter/material.dart';
import '../../../../core/formatters/amount_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/sale_model.dart';

class SaleStatusContent extends StatelessWidget {
  final PaymentResult result;
  final Color statusColor;
  final IconData statusIcon;
  final String statusTitle;
  final String statusSubtitle;
  final OperationModel? operation;
  final PrintStatus printStatus;
  final String printMessage;
  final VoidCallback? onRetryPrint;
  final VoidCallback onFinalize;

  const SaleStatusContent({
    super.key,
    required this.result,
    required this.statusColor,
    required this.statusIcon,
    required this.statusTitle,
    required this.statusSubtitle,
    this.operation,
    this.printStatus = PrintStatus.idle,
    this.printMessage = '',
    this.onRetryPrint,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),

        Icon(statusIcon, size: 64, color: statusColor),
        const SizedBox(height: 12),

        Text(
          statusTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        Text(
          statusSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            children: [
              _buildTicketRow('Nro. Operación', operation?.id ?? '---'),
              const Divider(height: 12),
              _buildTicketRow('Producto', operation?.productLabel ?? '---'),
              const Divider(height: 12),
              _buildTicketRow(
                'Monto',
                operation != null ? formatAmount(operation!.amount) : '---',
              ),
              const Divider(height: 12),
              _buildTicketRow('Tarjeta', operation?.cardNumber ?? '---'),
              const Divider(height: 12),
              _buildTicketRow('Código de respuesta', _responseCode(result)),
            ],
          ),
        ),

        const SizedBox(height: 10),
        _buildPrintStatus(context),

        const Spacer(),

        ElevatedButton(
          onPressed: onFinalize,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            'FINALIZAR',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrintStatus(BuildContext context) {
    switch (printStatus) {
      case PrintStatus.idle:
        return const SizedBox.shrink();
      case PrintStatus.printing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Imprimiendo ticket...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        );
      case PrintStatus.printed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Text(
              'Ticket impreso',
              style: TextStyle(fontSize: 13, color: Colors.green),
            ),
          ],
        );
      case PrintStatus.error:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    printMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ),
              ],
            ),
            if (onRetryPrint != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetryPrint,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('REIMPRIMIR'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                ),
              ),
            ],
          ],
        );
    }
  }

  String _responseCode(PaymentResult result) {
    switch (result) {
      case PaymentResult.approved:
        return '00 (Aprobado)';
      case PaymentResult.declined:
        return '51 (Fondos insuficientes)';
      case PaymentResult.connectionError:
        return '99 (Tiempo agotado)';
      case PaymentResult.voided:
        return '00 (ANULADA)';
    }
  }

  Widget _buildTicketRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
