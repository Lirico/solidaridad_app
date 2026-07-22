import 'package:flutter/material.dart';
import '../../domain/sale_model.dart';

@immutable
sealed class SalesState {
  final String currency;
  final double amount;
  final String cardNumber;
  final String cardHolder;
  final List<OperationModel> history;

  const SalesState({
    required this.currency,
    required this.amount,
    required this.cardNumber,
    required this.cardHolder,
    required this.history,
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

class SalesCompleted extends SalesState {
  final PaymentResult result;
  final String? operationNumber;
  final String? errorMessage;
  final String? errorCode;

  const SalesCompleted({
    required super.currency,
    required super.amount,
    required super.cardNumber,
    required super.cardHolder,
    required super.history,
    required this.result,
    this.operationNumber,
    this.errorMessage,
    this.errorCode,
  });

  bool get isSuccess => result == PaymentResult.approved;
}

class SalesInitialWithHistory extends SalesState {
  const SalesInitialWithHistory({required super.history})
    : super(currency: 'ARS', amount: 0.0, cardNumber: '', cardHolder: '');
}
