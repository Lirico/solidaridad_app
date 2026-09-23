import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/balance_repository.dart';
import 'balance_state.dart';

class BalanceCubit extends Cubit<BalanceState> {
  final BalanceRepository repository;

  BalanceCubit({required this.repository}) : super(const BalanceInitial());

  /// Guarda los datos de tarjeta capturados (manual o banda) antes de consultar.
  void setCardData({
    required String cardNumber,
    required String expirationDate,
    String entryMode = '012',
    String? track2,
  }) {
    emit(
      BalanceCardCaptured(
        cardNumber: cardNumber,
        expirationDate: expirationDate,
        entryMode: entryMode,
        track2: track2,
      ),
    );
  }

  Future<void> checkBalance({required String token}) async {
    final current = state;
    emit(
      BalanceChecking(
        cardNumber: current.cardNumber,
        expirationDate: current.expirationDate,
        entryMode: current.entryMode,
        track2: current.track2,
      ),
    );

    final result = await repository.checkBalance(
      token: token,
      cardNumber: current.cardNumber,
      expirationDate: current.expirationDate,
      entryMode: current.entryMode,
      track2: current.track2,
    );

    if (result.sessionExpired) {
      emit(const BalanceSessionExpired());
      return;
    }

    emit(
      BalanceCompleted(
        cardNumber: current.cardNumber,
        expirationDate: current.expirationDate,
        entryMode: current.entryMode,
        track2: current.track2,
        result: result,
      ),
    );
  }

  void reset() {
    emit(const BalanceInitial());
  }
}
