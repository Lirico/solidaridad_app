enum PaymentResult { approved, declined, connectionError }

class OperationModel {
  final String id;
  final String productCode;
  final String productLabel;
  final double amount;
  final String cardNumber;
  final PaymentResult result;
  final DateTime date;

  const OperationModel({
    required this.id,
    required this.productCode,
    required this.productLabel,
    required this.amount,
    required this.cardNumber,
    required this.result,
    required this.date,
  });

  factory OperationModel.fromJson(Map<String, dynamic> json) {
    final code = json['product'] as String? ?? '';
    return OperationModel(
      id: json['transaction_number'] as String? ?? '',
      productCode: code,
      productLabel: _labelForProductCode(code),
      amount: double.tryParse(json['amount'] as String? ?? '0') ?? 0.0,
      cardNumber: '•••• ${json['card_last4'] as String? ?? '0000'}',
      result: _parseStatus(json['status'] as String? ?? ''),
      date:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static String _labelForProductCode(String code) {
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

  static PaymentResult _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return PaymentResult.approved;
      case 'DECLINED':
        return PaymentResult.declined;
      case 'FAILED':
      case 'UNKNOWN':
      case 'PENDING':
      default:
        return PaymentResult.connectionError;
    }
  }
}

class SaleResponse {
  final bool isApproved;
  final String operationNumber;
  final String message;
  final String errorCode;
  final bool connectionError;
  final bool sessionExpired;

  const SaleResponse({
    required this.isApproved,
    required this.operationNumber,
    required this.message,
    required this.errorCode,
    this.connectionError = false,
    this.sessionExpired = false,
  });
}

class ProductInfo {
  final String code;
  final String label;

  const ProductInfo({required this.code, required this.label});

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }
}
