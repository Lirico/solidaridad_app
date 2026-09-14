import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/balance_model.dart';

class BalanceStatusContent extends StatelessWidget {
  final BalanceResult result;
  final VoidCallback onFinalize;

  const BalanceStatusContent({
    super.key,
    required this.result,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    if (result.status == BalanceStatus.approved) {
      return _buildTable(context);
    }
    return _buildError(context);
  }

  Widget _buildTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Saldo disponible',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'El saldo se consultó correctamente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
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
              const _BalanceHeaderRow(),
              const Divider(height: 1),
              for (final item in result.balances) _BalanceRow(item: item),
            ],
          ),
        ),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final bool isConnection = result.status == BalanceStatus.connectionError;
    final Color color =
        isConnection ? const Color(0xFFFF8C00) : const Color(0xFFE74C3C);
    final IconData icon =
        isConnection ? Icons.wifi_off_outlined : Icons.error_outline;
    final String title =
        isConnection ? 'Error de Conexión' : 'Consulta Rechazada';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          result.message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _BalanceHeaderRow extends StatelessWidget {
  const _BalanceHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Producto',
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            'Cantidad',
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final BalanceItem item;

  const _BalanceRow({required this.item});

  String get _unit => item.product == 'GRANEL' ? 'm3' : 'unidades';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${item.availableBalance.toStringAsFixed(2)} $_unit',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
