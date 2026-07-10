class OperationModel {
  final String id;
  final String currency;
  final double amount;
  final String cardNumber;
  final bool isSuccess;
  final DateTime date;

  const OperationModel({
    required this.id,
    required this.currency,
    required this.amount,
    required this.cardNumber,
    required this.isSuccess,
    required this.date,
  });
}
