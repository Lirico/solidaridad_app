import 'package:flutter_bloc/flutter_bloc.dart';
import 'sales_state.dart';
import '../../data/sales_repository.dart';

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository _repository;

  SalesCubit(this._repository) : super(SalesInitial());

  // 1. El botón CONTINUAR del formulario solo cambia el estado a modo "Revisión"
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
      ),
    );
  }

  // 2. Volver del resumen al formulario si se equivocó en algo
  void cancelReview() {
    emit(SalesInitial());
  }

  // 3. El botón CONFIRMAR PAGO procesa la transacción de forma definitiva contra AWS
  Future<void> confirmAndProcessSale({
    required String currency,
    required double amount,
    required String cardNumber,
  }) async {
    emit(SalesProcessing()); // Cambia a la animación de carga del PDF

    try {
      final isSuccess = await _repository.processGasSale(
        currency: currency,
        amount: amount,
        cardNumber: cardNumber,
      );

      if (isSuccess) {
        // Simulamos un ID de transacción para el comprobante
        emit(
          SalesSuccess(
            transactionId:
                'TXN_ID: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
            amount: amount,
            currency: currency,
          ),
        );
      } else {
        emit(
          SalesError(
            errorMessage: 'Fondos Insuficientes\n(Rechazo del Banco)',
            isNetworkError: false,
          ),
        );
      }
    } catch (e) {
      emit(
        SalesError(
          errorMessage:
              'No se pudo conectar con el servidor. Verifique su conexión.',
          isNetworkError: true,
        ),
      );
    }
  }
}
