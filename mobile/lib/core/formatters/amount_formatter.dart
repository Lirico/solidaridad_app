/// Formatea un monto para mostrarlo sin decimales cuando es un número entero.
///
/// Ejemplos:
/// - `100.0`  -> `100`
/// - `100.5`  -> `100.5`
/// - `100.50` -> `100.5`
String formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toInt().toString();
  }
  return amount.toString();
}
