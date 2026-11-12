import '../../batch_close/domain/batch_close_model.dart';
import 'balance_model.dart';

/// Suma el saldo en kg con la misma equivalencia del cierre de lote.
///
/// El catálogo no publica el peso por producto. `batchKgPerUnit` es la
/// equivalencia del mockup (garrafa de 10 kg = 10, granel 1:1). Cuando el
/// backend publique el peso, este cálculo se reemplaza. Ver G-P2-10.
double balanceKilograms(List<BalanceItem> items) {
  var total = 0.0;
  for (final item in items) {
    final perUnit = batchKgPerUnit[item.product];
    if (perUnit == null) continue;
    total += item.availableBalance * perUnit;
  }
  return total;
}
