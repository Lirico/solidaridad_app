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
