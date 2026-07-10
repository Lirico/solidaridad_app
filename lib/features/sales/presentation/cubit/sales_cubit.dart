import 'package:flutter_bloc/flutter_bloc.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  // Inicializamos el Cubit con el estado inicial nativo
  SalesCubit() : super(const SalesInitial());

  // 1. Al presionar "CONTINUAR", pasamos a modo Revisión arrastrando el historial actual
  void showReview({
    required String currency,
    required double amount,
    required String cardNumber,
    required String cardHolder,
  }) {
    emit(
      SalesReviewing(
        currency: currency,
        amount: amount,
        cardNumber: cardNumber,
        cardHolder: cardHolder,
        history: state.history, // Mantiene el historial que ya teníamos
      ),
    );
  }

  // 2. PASO 2: Procesamiento ISO hacia AWS guardando el resultado en la bitácora
  Future<void> sendIsoMessage() async {
    final currentCurrency = state.currency;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCardHolder = state.cardHolder;

    // Clonamos la lista de historial actual para no mutar el estado anterior directamente
    final currentHistory = List<OperationModel>.from(state.history);

    // Emitimos el estado de carga transaccional
    emit(
      SalesProcessing(
        currency: currentCurrency,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        history: currentHistory,
      ),
    );

    // Simulamos los 3 segundos de viaje del paquete de datos
    await Future.delayed(const Duration(seconds: 3));

    // Simulación: Al azar da aprobado o rechazado (80% éxito, 20% rebote)
    final bool isApproved = DateTime.now().millisecond % 5 != 0;

    // Generamos un ID de operación único basado en los últimos dígitos del timestamp
    final String opId =
        'OP-${DateTime.now().microsecondsSinceEpoch.toString().substring(10)}';

    // Creamos el registro de la transacción actual
    final newOperation = OperationModel(
      id: opId,
      currency: currentCurrency,
      amount: currentAmount,
      cardNumber: currentCardNumber.isNotEmpty
          ? currentCardNumber
          : '•••• 4321',
      isSuccess: isApproved,
      date: DateTime.now(),
    );

    // Insertamos la operación al principio (index 0) para que se vea arriba de todo en la lista
    currentHistory.insert(0, newOperation);

    if (isApproved) {
      emit(
        SalesSuccess(
          currency: currentCurrency,
          amount: currentAmount,
          cardNumber: currentCardNumber,
          cardHolder: currentCardHolder,
          operationNumber: opId,
          history: currentHistory, // Guardamos la lista con el éxito metido
        ),
      );
    } else {
      emit(
        SalesError(
          currency: currentCurrency,
          amount: currentAmount,
          cardNumber: currentCardNumber,
          cardHolder: currentCardHolder,
          errorMessage: 'La terminal reportó fondos insuficientes.',
          errorCode: '51',
          history: currentHistory, // Guardamos la lista con el rechazo metido
        ),
      );
    }
  }

  // 3. Resetea el formulario pero CONSERVA el historial acumulado del día
  void resetSale() {
    emit(SalesInitialWithHistory(history: state.history));
  }
}

// Pequeño helper por si al resetear la venta necesitás volver a SalesInitial sin perder la lista
class SalesInitialWithHistory extends SalesState {
  SalesInitialWithHistory({required super.history})
    : super(currency: 'ARS', amount: 0.0, cardNumber: '', cardHolder: '');
}
