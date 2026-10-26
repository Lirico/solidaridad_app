import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/sale_model.dart';
import '../../../../psdk/msr_card_data.dart';
import '../../data/sales_repository.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  static const String unconfirmedSaleMessage =
      'La venta sigue sin confirmar. Puede consultarla en el historial.';
  static const String blockedNewSaleMessage = 'Hay una venta sin confirmar.';

  final SalesRepository salesRepository;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _now;
  final Duration pollingTimeout;
  bool _polling = false;
  bool _pollingCancelled = false;
  bool _leaveRequested = false;

  SalesCubit({
    required this.salesRepository,
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
    this.pollingTimeout = const Duration(seconds: 30),
  }) : _wait = wait ?? Future<void>.delayed,
       _now = now ?? DateTime.now,
       super(const SalesLoading());

  /// Hay un cobro en curso que todavía puede cambiar de resultado.
  /// Una revisión de oficina no bloquea la venta siguiente.
  bool get blocksNewSale {
    final current = state;
    return current is SalesAwaitingAuthorization &&
        current.pendingReason != PendingSaleReason.underReview &&
        !current.mayStartNewSale;
  }

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
    } on DataLoadException catch (error) {
      emit(SalesHistoryLoadFailed(message: error.message));
    } catch (_) {
      emit(
        const SalesHistoryLoadFailed(
          message: 'Ocurrió un error inesperado. Reintente.',
        ),
      );
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
    if (blocksNewSale) return;
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
  }) {
    if (blocksNewSale) return;
    emit(
      SalesReviewing(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        cardNumber: cardNumber,
        cvv: cvv,
        expirationDate: expirationDate,
        history: state.history,
        idempotencyKey: generateIdempotencyKey(),
      ),
    );
  }

  /// Prepara la pantalla de revisión a partir de una lectura de banda
  /// magnética (MSR), sin pasar por el ingreso manual.
  ///
  /// La banda magnética no contiene CVV. La lectura completa los mismos datos
  /// que el ingreso manual y el vencimiento ya está en formato YYMM.
  void showReviewFromMsr(MsrCardData data) {
    if (blocksNewSale) return;
    emit(
      SalesReviewing(
        productCode: state.productCode,
        productLabel: state.productLabel,
        amount: state.amount,
        cardNumber: data.pan,
        cvv: '',
        expirationDate: data.expiryYyMm,
        history: state.history,
        idempotencyKey: generateIdempotencyKey(),
      ),
    );
  }

  Future<void> sendIsoMessage({required String token}) async {
    if (state is SalesProcessing || state is SalesAwaitingAuthorization) {
      return;
    }
    _leaveRequested = false;

    final currentProductCode = state.productCode;
    final currentProductLabel = state.productLabel;
    final currentAmount = state.amount;
    final currentCardNumber = state.cardNumber;
    final currentCvv = state.cvv;
    final currentExpirationDate = state.expirationDate;
    final currentIdempotencyKey = state.idempotencyKey;

    final currentHistory = List<OperationModel>.from(state.history);

    emit(
      SalesProcessing(
        productCode: currentProductCode,
        productLabel: currentProductLabel,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        history: currentHistory,
        idempotencyKey: currentIdempotencyKey,
      ),
    );

    Future<SaleResponse> register() {
      return salesRepository.registerSale(
        product: currentProductCode,
        amount: currentAmount.toString(),
        cardNumber: currentCardNumber,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        token: token,
        idempotencyKey: currentIdempotencyKey,
      );
    }

    var response = await register();
    if (response.connectionError && !_leaveRequested && !isClosed) {
      response = await register();
    }

    if (response.sessionExpired) {
      emit(const SalesSessionExpired());
      return;
    }

    if (response.isPending) {
      _emitPendingResponse(
        response: response,
        productCode: currentProductCode,
        productLabel: currentProductLabel,
        amount: currentAmount,
        cardNumber: currentCardNumber,
        cvv: currentCvv,
        expirationDate: currentExpirationDate,
        history: currentHistory,
        idempotencyKey: currentIdempotencyKey,
      );
      if (_leaveRequested || isClosed) {
        cancelPendingSalePolling();
        return;
      }
      await pollPendingSale(token: token);
      return;
    }

    _emitCompletedResponse(
      response: response,
      productCode: currentProductCode,
      productLabel: currentProductLabel,
      amount: currentAmount,
      cardNumber: currentCardNumber,
      cvv: currentCvv,
      expirationDate: currentExpirationDate,
      history: currentHistory,
      idempotencyKey: currentIdempotencyKey,
    );
  }

  /// Reanuda una venta observada como pendiente en el historial. Solo consulta
  /// su número de operación: no conserva ni vuelve a transmitir PAN, CVV o la
  /// clave de idempotencia original.
  Future<void> resumePendingSale({
    required String token,
    required OperationModel operation,
  }) async {
    if (!operation.isPending ||
        _polling ||
        state is SalesAwaitingAuthorization) {
      return;
    }
    _emitPendingResponse(
      response: SaleResponse(
        isApproved: false,
        operationNumber: operation.id,
        message: operation.userMessage ?? 'Operación en curso.',
        errorCode: 'PENDING',
        authorizationStatus: SaleAuthorizationStatus.pending,
        pendingReason: operation.pendingReason,
        pollAfterSeconds: operation.pollAfterSeconds ?? 2,
        mayStartNewSale: operation.mayStartNewSale,
      ),
      productCode: operation.productCode,
      productLabel: operation.productLabel,
      amount: operation.amount,
      cardNumber: operation.cardNumber,
      cvv: '',
      expirationDate: '',
      history: state.history,
      idempotencyKey: '',
    );
    await pollPendingSale(token: token);
  }

  /// Polls exactly at the interval supplied by the API. Transient failures do
  /// not change a pending authorization into a decline and never trigger POST.
  Future<void> pollPendingSale({required String token}) async {
    if (_polling || state is! SalesAwaitingAuthorization) return;
    _polling = true;
    _pollingCancelled = false;
    final startedAt = _now();

    try {
      while (!_pollingCancelled && !isClosed) {
        final current = state;
        if (current is! SalesAwaitingAuthorization) return;
        if (current.pendingReason == PendingSaleReason.underReview ||
            current.pollAfterSeconds == null) {
          return;
        }
        if (_now().difference(startedAt) >= pollingTimeout) {
          emit(_stoppedPolling(current, unconfirmedSaleMessage));
          return;
        }

        await _wait(Duration(seconds: current.pollAfterSeconds!));
        if (_pollingCancelled || isClosed) return;

        SaleResponse response;
        try {
          response = await salesRepository.getSaleStatus(
            token: token,
            transactionNumber: current.operationNumber,
          );
        } on SessionExpiredException {
          emit(const SalesSessionExpired());
          return;
        } on DataLoadException {
          // Conservamos la operación pendiente y volvemos a consultar en el
          // próximo intervalo indicado por la API.
          continue;
        }

        if (response.isPending) {
          _emitPendingResponse(
            response: response,
            productCode: current.productCode,
            productLabel: current.productLabel,
            amount: current.amount,
            cardNumber: current.cardNumber,
            cvv: current.cvv,
            expirationDate: current.expirationDate,
            history: current.history,
            idempotencyKey: current.idempotencyKey,
          );
          continue;
        }

        _emitCompletedResponse(
          response: response,
          productCode: current.productCode,
          productLabel: current.productLabel,
          amount: current.amount,
          cardNumber: current.cardNumber,
          cvv: current.cvv,
          expirationDate: current.expirationDate,
          history: current.history,
          idempotencyKey: current.idempotencyKey,
        );
        return;
      }
    } finally {
      _polling = false;
    }
  }

  /// Corta la espera visible. No vuelve a enviar la venta ni la da por
  /// rechazada: el servidor sigue hasta un resultado.
  void leaveUnconfirmedSale() {
    _leaveRequested = true;
    _pollingCancelled = true;
    final current = state;
    if (current is SalesAwaitingAuthorization && !current.pollingStopped) {
      emit(_stoppedPolling(current, unconfirmedSaleMessage));
    }
  }

  void cancelPendingSalePolling() {
    leaveUnconfirmedSale();
  }

  SalesAwaitingAuthorization _stoppedPolling(
    SalesAwaitingAuthorization current,
    String message,
  ) {
    return SalesAwaitingAuthorization(
      productCode: current.productCode,
      productLabel: current.productLabel,
      amount: current.amount,
      cardNumber: current.cardNumber,
      cvv: current.cvv,
      expirationDate: current.expirationDate,
      history: current.history,
      idempotencyKey: current.idempotencyKey,
      operationNumber: current.operationNumber,
      pendingReason: current.pendingReason,
      pollAfterSeconds: current.pollAfterSeconds,
      mayStartNewSale: current.mayStartNewSale,
      message: message,
      pollingStopped: true,
    );
  }

  void _emitPendingResponse({
    required SaleResponse response,
    required String productCode,
    required String productLabel,
    required double amount,
    required String cardNumber,
    required String cvv,
    required String expirationDate,
    required List<OperationModel> history,
    required String idempotencyKey,
  }) {
    emit(
      SalesAwaitingAuthorization(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        cardNumber: cardNumber,
        cvv: cvv,
        expirationDate: expirationDate,
        history: _upsertOperation(
          history,
          _operationFromResponse(
            response: response,
            productCode: productCode,
            productLabel: productLabel,
            amount: amount,
            cardNumber: cardNumber,
          ),
        ),
        idempotencyKey: idempotencyKey,
        operationNumber: response.operationNumber,
        pendingReason: response.pendingReason,
        pollAfterSeconds: response.pollAfterSeconds,
        mayStartNewSale: response.mayStartNewSale,
        message: response.message,
      ),
    );
  }

  void _emitCompletedResponse({
    required SaleResponse response,
    required String productCode,
    required String productLabel,
    required double amount,
    required String cardNumber,
    required String cvv,
    required String expirationDate,
    required List<OperationModel> history,
    required String idempotencyKey,
  }) {
    final paymentResult = _paymentResultFromResponse(response);
    final operation = _operationFromResponse(
      response: response,
      productCode: productCode,
      productLabel: productLabel,
      amount: amount,
      cardNumber: cardNumber,
    );
    emit(
      SalesCompleted(
        productCode: productCode,
        productLabel: productLabel,
        amount: amount,
        cardNumber: cardNumber,
        cvv: cvv,
        expirationDate: expirationDate,
        history: _upsertOperation(history, operation),
        idempotencyKey: idempotencyKey,
        result: paymentResult,
        operationNumber: response.operationNumber.isNotEmpty
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

  OperationModel _operationFromResponse({
    required SaleResponse response,
    required String productCode,
    required String productLabel,
    required double amount,
    required String cardNumber,
  }) {
    final normalizedCard = cardNumber.replaceAll(' ', '');
    final hiddenCard = normalizedCard.length >= 4
        ? '•••• ${normalizedCard.substring(normalizedCard.length - 4)}'
        : '•••• 4321';
    return OperationModel(
      id: response.operationNumber.isNotEmpty
          ? response.operationNumber
          : 'OP-ERR',
      productCode: productCode,
      productLabel: productLabel,
      amount: amount,
      cardNumber: hiddenCard,
      result: _paymentResultFromResponse(response),
      authorizationStatus: response.authorizationStatus,
      pendingReason: response.pendingReason,
      pollAfterSeconds: response.pollAfterSeconds,
      mayStartNewSale: response.mayStartNewSale,
      date: _now(),
      userMessage: response.message,
    );
  }

  PaymentResult _paymentResultFromResponse(SaleResponse response) {
    if (response.connectionError) return PaymentResult.connectionError;
    switch (response.authorizationStatus) {
      case SaleAuthorizationStatus.approved:
        return PaymentResult.approved;
      case SaleAuthorizationStatus.declined:
        return PaymentResult.declined;
      case SaleAuthorizationStatus.pending:
        return response.pendingReason == PendingSaleReason.underReview
            ? PaymentResult.underReview
            : PaymentResult.pending;
      case SaleAuthorizationStatus.failed:
        return PaymentResult.failed;
    }
  }

  List<OperationModel> _upsertOperation(
    List<OperationModel> history,
    OperationModel operation,
  ) {
    final updated = List<OperationModel>.from(history);
    final index = updated.indexWhere((item) => item.id == operation.id);
    if (index >= 0) {
      updated[index] = operation;
    } else {
      updated.insert(0, operation);
    }
    return updated;
  }

  void resetSale() {
    emit(SalesInitial());
  }

  /// Cierra el handoff visible de una operación bajo revisión sin descartarla.
  /// La operación se conserva para una consulta manual posterior y la próxima
  /// venta vuelve a generar su propia clave en [showReview].
  bool startNewSaleAfterReview() {
    final current = state;
    if (current is! SalesAwaitingAuthorization ||
        current.pendingReason != PendingSaleReason.underReview ||
        !current.mayStartNewSale) {
      return false;
    }

    _pollingCancelled = true;
    emit(SalesInitialWithHistory(history: current.history));
    return true;
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
    // cambian el estado real (VOIDED) o requieren verificación (UNDER_REVIEW).
    if (!result.isVoided && !result.isUnderReview && !result.isUnknown) {
      return result;
    }

    final PaymentResult mappedResult = result.isVoided
        ? PaymentResult.voided
        : result.isUnderReview
        ? PaymentResult.underReview
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

  @override
  Future<void> close() {
    _pollingCancelled = true;
    return super.close();
  }
}
