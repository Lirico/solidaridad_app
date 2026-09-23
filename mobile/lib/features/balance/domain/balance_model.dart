/// Resultado de una consulta de saldo (agregada sobre todos los productos).
enum BalanceStatus { approved, declined, connectionError }

/// Saldo de un producto concreto, listo para la tabla Producto | Cantidad.
class BalanceItem {
  final String product;
  final String label;
  final double availableBalance;

  const BalanceItem({
    required this.product,
    required this.label,
    required this.availableBalance,
  });

  factory BalanceItem.fromJson(Map<String, dynamic> json) {
    return BalanceItem(
      product: json['product'] as String? ?? '',
      label: json['label'] as String? ?? '',
      availableBalance:
          double.tryParse(json['available_balance'] as String? ?? '0') ?? 0.0,
    );
  }
}

class BalanceResult {
  final BalanceStatus status;
  final List<BalanceItem> balances;
  final String message;
  final bool connectionError;
  final bool sessionExpired;

  const BalanceResult({
    required this.status,
    required this.balances,
    required this.message,
    this.connectionError = false,
    this.sessionExpired = false,
  });
}
