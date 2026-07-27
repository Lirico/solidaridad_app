import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/sale_model.dart';
import '../../data/sales_repository.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository salesRepository;

  SalesCubit({required this.salesRepository})
    : super(SalesInitialWithHistory(history: _mockHistory()));

  static List<OperationModel> _mockHistory() {
    final now = DateTime.now();
    return [
      OperationModel(
        id: 'OP-20260714-001',
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 15250.00,
        cardNumber: '•••• 4582',
        result: PaymentResult.approved,
        date: now.subtract(const Duration(minutes: 12)),
      ),
      OperationModel(
        id: 'OP-20260714-002',
        productCode: 'GARRAFA_15',
        productLabel: 'Garrafa 15 kg',
        amount: 120.50,
        cardNumber: '•••• 9237',
        result: PaymentResult.approved,
        date: now.subtract(const Duration(hours: 1, minutes: 5)),
      ),
      OperationModel(
        id: 'OP-20260714-003',
        productCode: 'TUBO_45',
        productLabel: 'Tubo 45 kg',
        amount: 8900.75,
        cardNumber: '•••• 6712',
        result: PaymentResult.declined,
        date: now.subtract(const Duration(hours: 2, minutes: 30)),
      ),
      OperationModel(
        id: 'OP-20260713-004',
        productCode: 'GARRAFA_10',
        productLabel: 'Garrafa 10 kg',
        amount: 31200.00,
        cardNumber: '•••• 3348',
        result: PaymentResult.approved,
        date: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      OperationModel(
        id: 'OP-20260713-005',
        productCode: 'GRANEL',
        productLabel: 'Granel',
        amount: 85.00,
        cardNumber: '•••• 1056',
        result: PaymentResult.approved,
        date: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      OperationModel(
        id: 'OP-20260713-006',
        productCode: 'GARRAFA_15',
        productLabel: 'Garrafa 15 kg',
        amount: 6700.00,
        cardNumber: '•••• 7823',
        result: PaymentResult.declined,
        date: now.subtract(const Duration(days: 1, hours: 10)),
      ),
    ];
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
