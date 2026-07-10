import 'package:meta/meta.dart';

// --- MODELO SIMPLE PARA CADA OPERACIÓN ---
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

@immutable
abstract class SalesState {
  final String currency;
  final double amount;
  final String cardNumber;
  final String cardHolder;
  final List<OperationModel>
  history; // <-- NUEVO: Guardamos el historial global aquí

  const SalesState({
    required this.currency,
    required this.amount,
    required this.cardNumber,
    required this.cardHolder,
    required this.history, // <-- NUEVO
  });
}

class SalesInitial extends SalesState {
  const SalesInitial()
    : super(
        currency: 'ARS',
        amount: 0.0,
        cardNumber: '',
        cardHolder: '',
        history: const [],
      );
}

class SalesReviewing extends SalesState {
  const SalesReviewing({
    required super.currency,
    required super.amount,
    required super.cardNumber,
    required super.cardHolder,
    required super.history,
  });
}

class SalesProcessing extends SalesState {
  const SalesProcessing({
    required super.currency,
    required super.amount,
    required super.cardNumber,
    required super.cardHolder,
    required super.history,
  });
}

class SalesSuccess extends SalesState {
  final String operationNumber;
  const SalesSuccess({
    required super.currency,
    required super.amount,
    required super.cardNumber,
    required super.cardHolder,
    required super.history,
    required this.operationNumber,
  });
}

class SalesError extends SalesState {
  final String errorMessage;
  final String errorCode;
  const SalesError({
    required super.currency,
    required super.amount,
    required super.cardNumber,
    required super.cardHolder,
    required super.history,
    required this.errorMessage,
    required this.errorCode,
  });
}
