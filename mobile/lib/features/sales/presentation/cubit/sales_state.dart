import 'package:flutter/material.dart';
import '../../domain/sale_model.dart';

@immutable
sealed class SalesState {
  final String productCode;
  final String productLabel;
  final double amount;
  final String cardNumber;
  final String cvv;
  final String expirationDate;
  final String entryMode;
  final String? track2;
  final List<OperationModel> history;

  const SalesState({
    required this.productCode,
    required this.productLabel,
    required this.amount,
    required this.cardNumber,
    required this.cvv,
    required this.expirationDate,
    this.entryMode = '012',
    this.track2,
    required this.history,
  });
}

class SalesLoading extends SalesState {
  const SalesLoading()
    : super(
        productCode: '',
        productLabel: '',
        amount: 0.0,
        cardNumber: '',
        cvv: '',
        expirationDate: '',
        history: const [],
      );
}

class SalesInitial extends SalesState {
  const SalesInitial()
    : super(
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 0.0,
        cardNumber: '',
        cvv: '',
        expirationDate: '',
        history: const [],
      );
}

/// Estado intermedio emitido cuando el usuario selecciona producto y cantidad
/// en el formulario de venta, antes de ingresar los datos de la tarjeta.
class SalesProductSelected extends SalesState {
  const SalesProductSelected({
    required super.productCode,
    required super.productLabel,
    required super.amount,
    required super.history,
  }) : super(cardNumber: '', cvv: '', expirationDate: '');
}

class SalesReviewing extends SalesState {
  const SalesReviewing({
    required super.productCode,
    required super.productLabel,
    required super.amount,
    required super.cardNumber,
    required super.cvv,
    required super.expirationDate,
    super.entryMode,
    super.track2,
    required super.history,
  });
}

class SalesProcessing extends SalesState {
  const SalesProcessing({
    required super.productCode,
    required super.productLabel,
    required super.amount,
    required super.cardNumber,
    required super.cvv,
    required super.expirationDate,
    super.entryMode,
    super.track2,
    required super.history,
  });
}

class SalesCompleted extends SalesState {
  final PaymentResult result;
  final String? operationNumber;
  final String? errorMessage;
  final String? errorCode;

  const SalesCompleted({
    required super.productCode,
    required super.productLabel,
    required super.amount,
    required super.cardNumber,
    required super.cvv,
    required super.expirationDate,
    super.entryMode,
    super.track2,
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
    : super(
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 0.0,
        cardNumber: '',
        cvv: '',
        expirationDate: '',
      );
}

/// Emitted when the API returns 401 (token expired/invalid).
class SalesSessionExpired extends SalesState {
  const SalesSessionExpired()
    : super(
        productCode: '',
        productLabel: '',
        amount: 0.0,
        cardNumber: '',
        cvv: '',
        expirationDate: '',
        history: const [],
      );
}
