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
        statusTitle = 'VENTA EXITOSA';
      case PaymentResult.declined:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTitle = 'VENTA RECHAZADA';
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
        '${operation.date.day}/${operation.date.month}/${operation.date.year}';
    final time =
        '${operation.date.hour.toString().padLeft(2, '0')}:${operation.date.minute.toString().padLeft(2, '0')} hs';
    final rows = <MapEntry<String, String>>[
      MapEntry('Emisor:', defaults.issuerName),
      MapEntry('Tipo:', ReceiptFormatter.operationTypeLabel(operation.result)),
      MapEntry('Comercio:', defaults.establishmentName),
      MapEntry('Domicilio:', defaults.establishmentAddress),
      MapEntry('CUIT:', defaults.establishmentCuit),
      MapEntry('Cód. establecimiento:', defaults.establishmentCode),
      MapEntry('Fecha:', date),
      MapEntry('Hora:', time),
      MapEntry('Cupón:', defaults.couponNumber),
      MapEntry('Lote:', defaults.batchNumber),
      MapEntry('Terminal:', ReceiptFormatter.terminalId),
      MapEntry('Tarjeta:', ReceiptFormatter.maskPan(operation.cardNumber)),
      MapEntry('Autorización:', defaults.authorizationCode),
      MapEntry('ID Operación:', operation.id),
      MapEntry('Producto:', operation.productLabel),
      MapEntry('Importe:', formatAmount(operation.amount)),
      MapEntry('Moneda:', defaults.currency),
      MapEntry('Cuotas:', defaults.installments),
      MapEntry('Plan:', defaults.installmentPlan),
      if (operation.result == PaymentResult.voided)
        MapEntry('Cargo original:', defaults.originalChargeNumber),
      if (operation.userMessage != null &&
          operation.userMessage!.trim().isNotEmpty)
        MapEntry('Mensaje:', operation.userMessage!.trim()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 64),
              const SizedBox(height: 12),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 40, thickness: 1),
        for (final row in rows) _buildTicketRow(row.key, row.value),
        const Divider(height: 40, thickness: 1),
        const Center(
          child: Text(
            'GAS Terminal - Sistema de Distribución',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
