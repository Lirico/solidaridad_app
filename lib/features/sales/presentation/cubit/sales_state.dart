abstract class SalesState {}

// Pantalla 2: Formulario inicial
class SalesInitial extends SalesState {}

// Pantalla 3 (Parte A): El comerciante ve el ticket para revisar datos antes de enviar
class SalesReviewing extends SalesState {
  final String currency;
  final double amount;
  final String cardNumber;
  final String cardHolder;

  SalesReviewing({
    required this.currency,
    required this.amount,
    required this.cardNumber,
    required this.cardHolder,
  });
}

// Pantalla 3 (Parte B): Animación de carga congelada ("Procesando")
class SalesProcessing extends SalesState {}

class SalesLoading extends SalesState {}

// Pantalla 4: Respuestas finales del sistema
class SalesSuccess extends SalesState {
  final String transactionId;
  final double amount;
  final String currency;
  SalesSuccess({
    required this.transactionId,
    required this.amount,
    required this.currency,
  });
}

class SalesError extends SalesState {
  final String errorMessage;
  final bool isNetworkError; // Para diferenciar el botón de reintento del PDF
  SalesError({required this.errorMessage, this.isNetworkError = false});
}
