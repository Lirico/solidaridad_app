import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/sale_model.dart';
import '../../data/sales_repository.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository salesRepository;

  SalesCubit({required this.salesRepository}) : super(const SalesLoading());

  Future<void> loadHistory({
    required String token,
    int limit = 20,
    int offset = 0,
  }) async {
    emit(const SalesLoading());
    try {
      final items = await salesRepository.fetchHistory(
        token: token,
        limit: limit,
        offset: offset,
      );
      emit(SalesInitialWithHistory(history: items));
    } catch (_) {
      emit(SalesInitialWithHistory(history: const []));
    }
  }

  void showReview({
    required String productCode,
    required String productLabel,
    required double amount,
    required String cardNumber,
    required String cardHolder,
    required String cvv,
    required String expirationDate,
  }) {
    emit(
      SalesReviewing(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        cardNumber: cardNumber,
        cardHolder: cardHolder,
        cvv: cvv,
        expirationDate: expirationDate,
        history: state.history,
      ),
    );
  }

  Future<void> sendIsoMessage() async {
    final currentProductCode = state.productCode;
    final currentProductLabel = state.productLabel;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCardHolder = state.cardHolder;
    final currentCvv = state.cvv;
    final currentExpirationDate = state.expirationDate;

    final currentHistory = List<OperationModel>.from(state.history);

    emit(
      SalesProcessing(
        productCode: currentProductCode,
        productLabel: currentProductLabel,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        history: currentHistory,
      ),
    );

    final response = await salesRepository.registerSale(
      product: currentProductCode,
      amount: currentAmount.toString(),
      cardNumber: currentCardNumber,
      cvv: currentCvv,
      expirationDate: currentExpirationDate,
      token:
          'TOKEN_MOCK_SESION_FASE_0', // TODO: Enlazar con tu AuthCubit global en producción
    );

    final String hiddenCard = currentCardNumber.replaceAll(' ', '').length >= 4
        ? '•••• ${currentCardNumber.replaceAll(' ', '').substring(currentCardNumber.replaceAll(' ', '').length - 4)}'
        : '•••• 4321';

    final PaymentResult paymentResult = response.connectionError
        ? PaymentResult.connectionError
        : response.isApproved
        ? PaymentResult.approved
        : PaymentResult.declined;

    final newOperation = OperationModel(
      id: response.operationNumber.isNotEmpty
          ? response.operationNumber
          : 'OP-ERR',
      productCode: currentProductCode,
      productLabel: currentProductLabel,
      amount: currentAmount,
      cardNumber: hiddenCard,
      result: paymentResult,
      date: DateTime.now(),
    );

    currentHistory.insert(0, newOperation);

    emit(
      SalesCompleted(
        productCode: currentProductCode,
        productLabel: currentProductLabel,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cardHolder: currentCardHolder,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        history: currentHistory,
        result: paymentResult,
        operationNumber: paymentResult == PaymentResult.approved
            ? response.operationNumber
            : null,
        errorMessage: paymentResult != PaymentResult.approved
            ? response.message
            : null,
        errorCode: paymentResult != PaymentResult.approved
            ? response.errorCode
            : null,
      ),
    );
  }

  void resetSale() {
    emit(SalesInitial());
  }
}
