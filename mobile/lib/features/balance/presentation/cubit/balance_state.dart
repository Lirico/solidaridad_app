import 'package:flutter/material.dart';

import '../../domain/balance_model.dart';

@immutable
sealed class BalanceState {
  final String cardNumber;
  final String expirationDate;
  final String entryMode;
  final String? track2;

  const BalanceState({
    required this.cardNumber,
    required this.expirationDate,
    this.entryMode = '012',
    this.track2,
  });
}

class BalanceInitial extends BalanceState {
  const BalanceInitial() : super(cardNumber: '', expirationDate: '');
}

class BalanceCardCaptured extends BalanceState {
  const BalanceCardCaptured({
    required super.cardNumber,
    required super.expirationDate,
    super.entryMode,
    super.track2,
  });
}

class BalanceChecking extends BalanceState {
  const BalanceChecking({
    required super.cardNumber,
    required super.expirationDate,
    super.entryMode,
    super.track2,
  });
}

class BalanceCompleted extends BalanceState {
  final BalanceResult result;

  const BalanceCompleted({
    required super.cardNumber,
    required super.expirationDate,
    super.entryMode,
    super.track2,
    required this.result,
  });
}

/// Emitido cuando la API responde 401 (token inválido/expirado).
class BalanceSessionExpired extends BalanceState {
  const BalanceSessionExpired() : super(cardNumber: '', expirationDate: '');
}
