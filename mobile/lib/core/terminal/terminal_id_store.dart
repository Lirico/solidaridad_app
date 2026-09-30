import 'package:shared_preferences/shared_preferences.dart';

/// Hint de laboratorio. Vacío salvo que el build pase
/// `--dart-define=INSTALLATION_ID=...`. No se envía al backend hasta guardarlo.
const String labInstallationId = String.fromEnvironment('INSTALLATION_ID');

/// Código de terminal que el procesador espera en el login (1 a 8 caracteres).
class TerminalId {
  static const int maxLength = 8;

  /// Recorta espacios. Devuelve null si queda vacío o supera [maxLength].
  static String? normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }
    return trimmed;
  }
}

/// Lectura y escritura del identificador de terminal en el equipo.
abstract class TerminalIdStore {
  Future<String?> read();

  /// Persiste [raw] si normaliza a 1–8 caracteres. Devuelve el valor guardado,
  /// o null si [raw] es vacío o demasiado largo (no escribe en ese caso).
  Future<String?> save(String raw);
}

/// Almacén en memoria. Lo usan los tests y cualquier doble que no toque disco.
class MemoryTerminalIdStore implements TerminalIdStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<String?> save(String raw) async {
    final normalized = TerminalId.normalize(raw);
    if (normalized == null) {
      return null;
    }
    _value = normalized;
    return normalized;
  }
}

/// Almacén en SharedPreferences. Un APK en dos equipos no comparte este valor.
class SharedPreferencesTerminalIdStore implements TerminalIdStore {
  SharedPreferencesTerminalIdStore({this.preferences});

  static const String storageKey = 'installation_id';

  final SharedPreferences? preferences;

  Future<SharedPreferences> _prefs() async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<String?> read() async {
    final raw = (await _prefs()).getString(storageKey);
    if (raw == null) {
      return null;
    }
    return TerminalId.normalize(raw);
  }

  @override
  Future<String?> save(String raw) async {
    final normalized = TerminalId.normalize(raw);
    if (normalized == null) {
      return null;
    }
    await (await _prefs()).setString(storageKey, normalized);
    return normalized;
  }
}
