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
  }) {
    emit(
      BalanceCardCaptured(
        cardNumber: cardNumber,
        expirationDate: expirationDate,
      ),
    );
  }

  Future<void> checkBalance({required String token}) async {
    final current = state;
    emit(
      BalanceChecking(
        cardNumber: current.cardNumber,
        expirationDate: current.expirationDate,
      ),
    );

    final result = await repository.checkBalance(
      token: token,
      cardNumber: current.cardNumber,
      expirationDate: current.expirationDate,
    );

    if (result.sessionExpired) {
      emit(const BalanceSessionExpired());
      return;
    }

    emit(
      BalanceCompleted(
        cardNumber: current.cardNumber,
        expirationDate: current.expirationDate,
        result: result,
      ),
    );
  }

  void reset() {
    emit(const BalanceInitial());
  }
}
