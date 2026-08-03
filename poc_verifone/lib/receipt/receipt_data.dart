/// Ticket fields aligned with API list/detail + local capture context.
///
/// Backend today: [transactionNumber], [status], [userMessage], [createdAt],
/// and list item extras [product], [amount], [cardLast4].
class ReceiptData {
  const ReceiptData({
    required this.transactionNumber,
    required this.status,
    required this.userMessage,
    required this.createdAt,
    required this.product,
    required this.productLabel,
    required this.amount,
    required this.cardLast4,
    this.cardHolder,
    this.merchantName = 'GAS Terminal — Solidaridad',
  });

  final String transactionNumber;
  final String status;
  final String userMessage;
  final DateTime createdAt;
  final String product;
  final String productLabel;
  final String amount;
  final String cardLast4;
  final String? cardHolder;
  final String merchantName;

  bool get isApproved => status.toUpperCase() == 'APPROVED';

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'APROBADA';
      case 'DECLINED':
        return 'RECHAZADA';
      case 'FAILED':
      case 'UNKNOWN':
      case 'PENDING':
        return status.toUpperCase();
      default:
        return status.toUpperCase();
    }
  }

  String get maskedPan => '•••• $cardLast4';

  /// Build from a map shaped like `TransactionItemResponse` (+ optional holder).
  factory ReceiptData.fromTransactionJson(
    Map<String, dynamic> json, {
    String? cardHolder,
    String? productLabel,
  }) {
    final product = json['product'] as String? ?? '';
    return ReceiptData(
      transactionNumber: json['transaction_number'] as String? ?? '',
      status: json['status'] as String? ?? '',
      userMessage: json['user_message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      product: product,
      productLabel: productLabel ?? _labelForProduct(product),
      amount: json['amount'] as String? ?? '0',
      cardLast4: json['card_last4'] as String? ?? '0000',
      cardHolder: cardHolder,
    );
  }

  static String _labelForProduct(String code) {
    switch (code) {
      case 'GARRAFA_10':
        return 'Garrafa 10 kg';
      case 'GARRAFA_15':
        return 'Garrafa 15 kg';
      case 'GARRAFA_30':
        return 'Garrafa 30 kg';
      case 'TUBO_45':
        return 'Tubo 45 kg';
      case 'GRANEL':
        return 'Granel';
      default:
        return code;
    }
  }
}
