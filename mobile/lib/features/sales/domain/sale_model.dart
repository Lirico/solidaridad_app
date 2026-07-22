enum PaymentResult { approved, declined, connectionError }

class OperationModel {
  final String id;
  final String currency;
  final double amount;
  final String cardNumber;
  final PaymentResult result;
  final DateTime date;

  const OperationModel({
    required this.id,
    required this.currency,
    required this.amount,
    required this.cardNumber,
    required this.result,
    required this.date,
  });
}

class SaleResponse {
  final bool isApproved;
  final String operationNumber;
  final String message;
  final String errorCode;
  final bool connectionError;

  const SaleResponse({
    required this.isApproved,
    required this.operationNumber,
    required this.message,
    required this.errorCode,
    this.connectionError = false,
  });
}
