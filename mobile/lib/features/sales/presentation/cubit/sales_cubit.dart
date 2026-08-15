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
    } on SessionExpiredException {
      emit(const SalesSessionExpired());
    } catch (_) {
      emit(SalesInitialWithHistory(history: const []));
    }
  }

  /// Guarda el producto y la cantidad seleccionados en el formulario de venta,
  /// para que la pantalla de ingreso manual de tarjeta pueda continuar el flujo
  /// sin perder estos datos intermedios.
  void setProductAndAmount({
    required String productCode,
    required String productLabel,
    required double amount,
  }) {
    emit(
      SalesProductSelected(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        history: state.history,
      ),
    );
  }

  void showReview({
    required String productCode,
    required String productLabel,
    required double amount,
    required String cardNumber,
    required String cvv,
    required String expirationDate,
    String entryMode = '012',
    String? track2,
  }) {
    emit(
      SalesReviewing(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        cardNumber: cardNumber,
        cvv: cvv,
        expirationDate: expirationDate,
        entryMode: entryMode,
        track2: track2,
        history: state.history,
      ),
    );
  }

  Future<void> sendIsoMessage({required String token}) async {
    final currentProductCode = state.productCode;
    final currentProductLabel = state.productLabel;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCvv = state.cvv;
    final currentExpirationDate = state.expirationDate;
    final currentEntryMode = state.entryMode;
    final currentTrack2 = state.track2;

    final currentHistory = List<OperationModel>.from(state.history);

    emit(
      SalesProcessing(
        productCode: currentProductCode,
        productLabel: currentProductLabel,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        entryMode: currentEntryMode,
        track2: currentTrack2,
        history: currentHistory,
      ),
    );

    final response = await salesRepository.registerSale(
      product: currentProductCode,
      amount: currentAmount.toString(),
      cardNumber: currentCardNumber,
      cvv: currentCvv,
      expirationDate: currentExpirationDate,
      entryMode: currentEntryMode,
      track2: currentTrack2,
      token: token,
    );

    if (response.sessionExpired) {
      emit(const SalesSessionExpired());
      return;
    }

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

  /// Anula una venta aprobada llamando a la API y actualiza la operación
  /// en el historial en memoria con el resultado.
  Future<VoidResult> voidSale({
    required String token,
    required String transactionNumber,
    required String cardNumber,
    String? expirationDate,
  }) async {
    VoidResult result;
    try {
      result = await salesRepository.voidTransaction(
        token: token,
        transactionNumber: transactionNumber,
        cardNumber: cardNumber,
        expirationDate: expirationDate,
      );
    } on SessionExpiredException {
      emit(const SalesSessionExpired());
      return const VoidResult.sessionExpiredResult();
    }

    if (result.sessionExpired) {
      emit(const SalesSessionExpired());
      return result;
    }

    // La API deja la venta original en APPROVED cuando la anulación es
    // rechazada o falla: solo reflejamos en el historial los casos que
    // cambian el estado real (VOIDED) o quedan ambiguos (UNKNOWN).
    if (!result.isVoided && !result.isUnknown) {
      return result;
    }

    final PaymentResult mappedResult = result.isVoided
        ? PaymentResult.voided
        : PaymentResult.connectionError;

    final updatedHistory = state.history.map((op) {
      if (op.id == transactionNumber) {
        return OperationModel(
          id: op.id,
          productCode: op.productCode,
          productLabel: op.productLabel,
          amount: op.amount,
          cardNumber: op.cardNumber,
          result: mappedResult,
          date: op.date,
          userMessage: result.message,
        );
      }
      return op;
    }).toList();

    emit(SalesInitialWithHistory(history: updatedHistory));
    return result;
  }

  /// Appends more history items (used for pagination / load-more).
  void appendHistory(List<OperationModel> items) {
    emit(SalesInitialWithHistory(history: [...state.history, ...items]));
  }
}
