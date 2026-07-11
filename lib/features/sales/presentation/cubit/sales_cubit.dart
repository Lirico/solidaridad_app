import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/sale_model.dart';
import '../../data/sales_repository.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository _salesRepository;

  SalesCubit({required this._salesRepository}) : super(const SalesInitial());

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

  Future<void> sendIsoMessage() async {
    final currentCurrency = state.currency;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCardHolder = state.cardHolder;

    final currentHistory = List<OperationModel>.from(state.history);

    emit(
      SalesProcessing(
        currency: currentCurrency,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        history: currentHistory,
      ),
    );

    final response = await _salesRepository.registerGasSale(
      currency: currentCurrency,
      amount: currentAmount,
      cardNumber: currentCardNumber,
      cardHolder: currentCardHolder,
      token:
          'TOKEN_MOCK_SESION_FASE_0', // TODO: Enlazar con tu AuthCubit global en producción
    );

    final String hiddenCard = currentCardNumber.replaceAll(' ', '').length >= 4
        ? '•••• ${currentCardNumber.replaceAll(' ', '').substring(currentCardNumber.replaceAll(' ', '').length - 4)}'
        : '•••• 4321';

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

    currentHistory.insert(0, newOperation);

    emit(
      SalesCompleted(
        currency: currentCurrency,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        history: currentHistory,
        isSuccess: response.isApproved,
        operationNumber: response.isApproved ? response.operationNumber : null,
        errorMessage: response.isApproved ? null : response.message,
        errorCode: response.isApproved ? null : response.errorCode,
      ),
    );
  }

  void resetSale() {
    emit(SalesInitial());
  }
}
