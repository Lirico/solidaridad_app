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
    // toman los primeros 4 dígitos después del `=`. Si ese `=` no deja 4
    // dígitos, son los 4 que siguen al PAN.
    final String expiryYyMm = _extractExpiryYyMm(
      (tags['expiry'] ?? '') as String,
      track2,
      pan,
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
  ///
  /// Si el `=` no deja 4 dígitos (no está, o es el cierre de la pista), los 4
  /// dígitos que siguen al [pan] son el vencimiento. Si no alcanzan, la fecha
  /// queda vacía.
  static String _extractExpiryYyMm(
    String tagsExpiry,
    String track2,
    String pan,
  ) {
    if (tagsExpiry.isNotEmpty) return tagsExpiry;

    final int eq = track2.indexOf('=');
    if (eq >= 0) {
      final String afterSeparator = _firstFourDigits(track2.substring(eq + 1));
      if (afterSeparator.length == 4) return afterSeparator;
    }
    return _expiryAfterPan(track2, pan);
  }

  /// Primeros 4 dígitos de [source]. Los caracteres que no son dígitos se
  /// saltean al inicio y cortan la lectura una vez que ya hay dígitos.
  static String _firstFourDigits(String source) {
    final StringBuffer digits = StringBuffer();
    for (final int rune in source.runes) {
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

  /// Cuatro dígitos de vencimiento inmediatamente después del PAN.
  ///
  /// Corre cuando el `=` no deja cuatro dígitos. Se compara la secuencia de
  /// dígitos: si no empieza con el PAN, o no sobran 4 dígitos, no hay fecha.
  static String _expiryAfterPan(String track2, String pan) {
    final String panDigits = _digitsOnly(pan);
    if (panDigits.isEmpty) return '';
    final String trackDigits = _digitsOnly(track2);
    if (!trackDigits.startsWith(panDigits)) return '';
    final String rest = trackDigits.substring(panDigits.length);
    if (rest.length < 4) return '';
    return rest.substring(0, 4);
  }

  static String _digitsOnly(String value) {
    final StringBuffer digits = StringBuffer();
    for (final int rune in value.runes) {
      final String ch = String.fromCharCode(rune);
      if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) {
        digits.write(ch);
      }
    }
    return digits.toString();
  }
}
