import 'package:flutter/material.dart';
import '../../../../core/formatters/amount_formatter.dart';
import '../../../sales/domain/receipt_defaults.dart';
import '../../../sales/domain/receipt_formatter.dart';
import '../../../sales/domain/sale_model.dart';

class SaleDetailTicket extends StatelessWidget {
  final OperationModel operation;
  final ReceiptDefaults defaults;

  const SaleDetailTicket({
    super.key,
    required this.operation,
    required this.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;

    switch (operation.result) {
      case PaymentResult.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'Aprobada';
      case PaymentResult.declined:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        final code = operation.responseCode?.trim() ?? '';
        statusTitle = code.isEmpty ? 'Denegada' : 'Denegada ($code)';
      case PaymentResult.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusTitle = 'VENTA EN PROCESO';
      case PaymentResult.underReview:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.manage_search;
        statusTitle = 'VENTA EN VERIFICACIÓN';
      case PaymentResult.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        statusTitle = 'ERROR DE AUTORIZACIÓN';
      case PaymentResult.connectionError:
        statusColor = Colors.orange;
        statusIcon = Icons.wifi_off;
        statusTitle = 'ERROR DE CONEXIÓN';
      case PaymentResult.voided:
        statusColor = Colors.grey;
        statusIcon = Icons.undo;
        statusTitle = 'VENTA ANULADA';
    }

    final date =
        _two(operation.date.day) +
        '/${_two(operation.date.month)}/${operation.date.year}';
    final time =
        '${_two(operation.date.hour)}:${_two(operation.date.minute)}:${_two(operation.date.second)}';
    final rows = <String>[
      'Cód. establecimiento: ${defaults.establishmentCode}',
      'Cupón: ${defaults.couponNumber}',
      'Lote: ${defaults.batchNumber}',
      'Terminal: ${ReceiptFormatter.terminalId}',
      'Tarjeta: ${ReceiptFormatter.maskPan(operation.cardNumber)}',
      'Autorización: ${defaults.authorizationCode}',
      'Op: ${operation.id}',
      'Producto: ${operation.productLabel}',
      'Importe: ${formatAmount(operation.amount)}',
      'Moneda: ${defaults.currency}',
      'Cuotas: ${defaults.installments}',
      'Plan: ${defaults.installmentPlan}',
      if (operation.result == PaymentResult.voided)
        'Cargo original: ${defaults.originalChargeNumber}',
      if (operation.result != PaymentResult.declined &&
          operation.userMessage != null &&
          operation.userMessage!.trim().isNotEmpty)
        'Mensaje: ${operation.userMessage!.trim()}',
    ];
    final declineReason = operation.result == PaymentResult.declined
        ? operation.userMessage?.trim() ?? ''
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(
              child: Column(
                children: [
                  Text(
                    defaults.issuerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ReceiptFormatter.operationTypeLabel(operation.result),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 28),
        Center(
          child: Text(
            defaults.establishmentName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            defaults.establishmentAddress,
            textAlign: TextAlign.center,
          ),
        ),
        Center(
          child: Text(defaults.establishmentCuit, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 32),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              row,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 40),
              const SizedBox(height: 8),
              Text(
                statusTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              if (declineReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(declineReason, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        if (operation.result != PaymentResult.declined) ...[
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Firma: '),
              Expanded(
                child: Text(
                  '.' * 80,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
