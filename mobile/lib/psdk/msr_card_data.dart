/// Datos de tarjeta leídos por banda magnética (MSR), tipados y listos para
/// consumir desde la UI.
///
/// Centraliza el parseo del payload crudo que devuelve [PsdkBridge.readMsr]
/// (que mezcla `msr` y `tags`), de modo que la pantalla no tenga que conocer
/// la forma interna del bridge.
class MsrCardData {
  const MsrCardData({
    required this.pan,
    required this.expiryYyMm,
    required this.track2,
    this.name = '',
    this.serviceCode = '',
  });

  /// Número de tarjeta (PAN) en claro, tal como lo devuelve la terminal.
  final String pan;

  /// Vencimiento en formato YYMM (ej. "3012" → 12/30).
  final String expiryYyMm;

  /// Track2 sin sentinelas (formato ";PAN=EXPIRY?SERVICE").
  final String track2;

  /// Nombre del titular (si la terminal lo devuelve).
  final String name;

  /// Service code de la banda (ej. "101").
  final String serviceCode;

  /// Vencimiento en formato MMYY (ej. "3012" → "1230"), listo para la API.
  String get expiryMmYy {
    if (expiryYyMm.length != 4) return expiryYyMm;
    return expiryYyMm.substring(2) + expiryYyMm.substring(0, 2);
  }

  /// Parsea el payload crudo del bridge y devuelve un [MsrCardData].
  ///
  /// El bridge nativo setea `ok` solo cuando `code == OK`, pero en esta
  /// terminal la lectura devuelve `ERR_EXECUTION` con datos claros en `tags`
  /// (`hasClearData == true`). Por eso el éxito se determina por
  /// `hasClearData` y este factory solo se invoca cuando ya se validó eso.
  factory MsrCardData.fromBridge(Map<String, dynamic> result) {
    final Map<String, dynamic> tags = result['tags'] is Map
        ? Map<String, dynamic>.from(result['tags'])
        : <String, dynamic>{};
    final Map<String, dynamic> msr = result['msr'] is Map
        ? Map<String, dynamic>.from(result['msr'])
        : <String, dynamic>{};

    final String pan = (tags['pan'] ?? msr['panAscii'] ?? '') as String;
    final String track2 = (tags['track2'] ?? msr['track2'] ?? '') as String;

    // El vencimiento puede venir en tags['expiry'] (YYMM). Si viene vacío, se
    // toman los primeros 4 dígitos después del `=` del track2: en la banda
    // real el service code va pegado (`;PAN=3012101?` → `3012`).
    final String expiryYyMm = _extractExpiryYyMm(
      (tags['expiry'] ?? '') as String,
      track2,
    );

    return MsrCardData(
      pan: pan,
      expiryYyMm: expiryYyMm,
      track2: track2,
      name: (msr['name'] ?? '') as String,
      serviceCode: (msr['serviceCode'] ?? '') as String,
    );
  }

  /// Devuelve el vencimiento en formato YYMM.
  ///
  /// Si [tagsExpiry] ya trae un valor (YYMM) se usa tal cual. Si viene vacío,
  /// se toman los primeros 4 dígitos después del `=` del track2. En la banda
  /// real el vencimiento no queda solo entre `=` y `?`: sigue el service code
  /// (`;PAN=3012101?` → `3012`).
  static String _extractExpiryYyMm(String tagsExpiry, String track2) {
    if (tagsExpiry.isNotEmpty) return tagsExpiry;

    final int eq = track2.indexOf('=');
    if (eq < 0) return '';
    final StringBuffer digits = StringBuffer();
    for (final int rune in track2.substring(eq + 1).runes) {
      final String ch = String.fromCharCode(rune);
      final bool isDigit = ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;
      if (!isDigit) {
        if (digits.isNotEmpty) break;
        continue;
      }
      digits.write(ch);
      if (digits.length == 4) return digits.toString();
    }
    return '';
  }
}
