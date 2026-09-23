/// Formatea una cantidad con separador de miles `.` y decimales `,` (es-AR).
///
/// Ejemplos:
/// - `formatQuantityEs(1200)`   -> `1.200`
/// - `formatQuantityEs(2055)`   -> `2.055`
/// - `formatQuantityEs(1234.5)` -> `1.234,5`
///
/// Se implementa a mano porque el proyecto no depende de `intl` (ver
/// `pubspec.yaml`): agregar esa dependencia solo por el formato de un resumen
/// no se justifica.
String formatQuantityEs(double value, {int decimals = 0}) {
  final String raw = value.abs().toStringAsFixed(decimals);
  final List<String> parts = raw.split('.');
  final String integerPart = parts.first;

  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < integerPart.length; i++) {
    if (i > 0 && (integerPart.length - i) % 3 == 0) {
      grouped.write('.');
    }
    grouped.write(integerPart[i]);
  }

  final String sign = value < 0 ? '-' : '';
  if (parts.length > 1) {
    return '$sign$grouped,${parts[1]}';
  }
  return '$sign$grouped';
}

/// Máxima precisión de cantidad que acepta el backend (`AMOUNT_EXPONENT = 2`).
const int quantityMaxDecimals = 2;

/// Como [formatQuantityEs] pero con la precisión necesaria: hasta
/// [quantityMaxDecimals] decimales y sin ceros finales.
///
/// Se usa donde esconder la fracción cambia el número mostrado (una venta de
/// 5,5 unidades no son 6): hoy no redondear a entero es una decisión de
/// visualización del Cierre de Lote.
///
/// Ejemplos:
/// - `formatQuantityEsExact(37.5)`  -> `37,5`
/// - `formatQuantityEsExact(18.75)` -> `18,75`
/// - `formatQuantityEsExact(1200)`  -> `1.200`
String formatQuantityEsExact(
  double value, {
  int maxDecimals = quantityMaxDecimals,
}) {
  if (maxDecimals <= 0) return formatQuantityEs(value);

  String candidate = value.abs().toStringAsFixed(maxDecimals);
  while (candidate.endsWith('0')) {
    candidate = candidate.substring(0, candidate.length - 1);
  }
  if (candidate.endsWith('.')) {
    candidate = candidate.substring(0, candidate.length - 1);
  }

  final int comma = candidate.indexOf('.');
  final int used = comma < 0 ? 0 : candidate.length - comma - 1;
  // Reusa [formatQuantityEs] para agrupar miles y resolver el signo.
  return formatQuantityEs(value, decimals: used);
}
