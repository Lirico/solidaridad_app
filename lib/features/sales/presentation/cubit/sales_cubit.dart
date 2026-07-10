import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sales_repository.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  // Declaramos la dependencia del repositorio real
  final SalesRepository _salesRepository;

  SalesCubit({required SalesRepository salesRepository})
    : _salesRepository = salesRepository,
      super(const SalesInitial());

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
        history: state.history,
      ),
    );
  }

  // 2. CONECTADO POR HTTP: Procesamiento transaccional real contra la API en AWS
  Future<void> sendIsoMessage() async {
    final currentCurrency = state.currency;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCardHolder = state.cardHolder;

    // Clonamos la lista de historial actual para no mutar el estado anterior directamente
    final currentHistory = List<OperationModel>.from(state.history);

    // Emitimos el estado de carga transaccional nativo
    emit(
      SalesProcessing(
        currency: currentCurrency,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        history: currentHistory,
      ),
    );

    // Invocamos la petición HTTP real al repositorio de la Fase 0
    final response = await _salesRepository.registerGasSale(
      currency: currentCurrency,
      amount: currentAmount,
      cardNumber: currentCardNumber,
      cardHolder: currentCardHolder,
      token:
          'TOKEN_MOCK_SESION_FASE_0', // TODO: Enlazar con tu AuthCubit global en producción
    );

    // Enmascaramos el PAN (número completo) para cumplir la regla de auditoría del instructivo
    final String hiddenCard = currentCardNumber.replaceAll(' ', '').length >= 4
        ? '•••• ${currentCardNumber.replaceAll(' ', '').substring(currentCardNumber.replaceAll(' ', '').length - 4)}'
        : '•••• 4321';

    // Creamos el registro consolidado para la bitácora local del comercio
    final newOperation = OperationModel(
      id: response.operationNumber.isNotEmpty
          ? response.operationNumber
          : 'OP-ERR',
      currency: currentCurrency,
      amount: currentAmount,
      cardNumber: hiddenCard,
      isSuccess: response.isApproved,
      date: DateTime.now(),
    );

    // Insertamos la operación arriba de todo (index 0) para el ListView
    currentHistory.insert(0, newOperation);

    if (response.isApproved) {
      emit(
        SalesSuccess(
          currency: currentCurrency,
          amount: currentAmount,
          cardNumber: currentCardNumber,
          cardHolder: currentCardHolder,
          operationNumber: response.operationNumber,
          history: currentHistory,
        ),
      );
    } else {
      emit(
        SalesError(
          currency: currentCurrency,
          amount: currentAmount,
          cardNumber: currentCardNumber,
          cardHolder: currentCardHolder,
          errorMessage: response.message,
          errorCode: response.errorCode,
          history: currentHistory,
        ),
      );
    }
  }

  // 3. Resetea el formulario pero CONSERVA el historial acumulado del día
  void resetSale() {
    emit(SalesInitialWithHistory(history: state.history));
  }
}

class SalesInitialWithHistory extends SalesState {
  const SalesInitialWithHistory({required super.history})
    : super(currency: 'ARS', amount: 0.0, cardNumber: '', cardHolder: '');
}
