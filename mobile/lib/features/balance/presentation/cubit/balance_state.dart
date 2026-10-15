import 'package:flutter/material.dart';

import '../../domain/balance_model.dart';

@immutable
sealed class BalanceState {
  final String cardNumber;
  final String expirationDate;

  const BalanceState({
    required this.cardNumber,
    required this.expirationDate,
  });
}

class BalanceInitial extends BalanceState {
  const BalanceInitial() : super(cardNumber: '', expirationDate: '');
}

class BalanceCardCaptured extends BalanceState {
  const BalanceCardCaptured({
    required super.cardNumber,
    required super.expirationDate,
  });
}

class BalanceChecking extends BalanceState {
  const BalanceChecking({
    required super.cardNumber,
    required super.expirationDate,
  });
}

class BalanceCompleted extends BalanceState {
  final BalanceResult result;

  const BalanceCompleted({
    required super.cardNumber,
    required super.expirationDate,
    required this.result,
  });
}

/// Emitido cuando la API responde 401 (token inválido/expirado).
class BalanceSessionExpired extends BalanceState {
  const BalanceSessionExpired() : super(cardNumber: '', expirationDate: '');
}
