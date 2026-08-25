import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../psdk/psdk_bridge.dart';
import '../config/api_config.dart';

/// Identificador físico del terminal (Verifone), configurado en el device.
///
/// Se puede inyectar en build con `--dart-define=LOGICAL_DEVICE_ID=...`. Es el
/// **fallback** de lab: cuando no hay hardware Verifone conectado (o el bridge
/// no puede leer el device), se usa este valor. En un terminal real, el
/// `logical_device_id` se lee del hardware vía [PsdkBridge.getDeviceInfo].
const String kLogicalDeviceId = String.fromEnvironment(
  'LOGICAL_DEVICE_ID',
  defaultValue: 'V660P-DEMO-0001',
);

/// Clave de SharedPreferences donde se persiste el `installation_id` real
/// resuelto por el backend (no mockeado).
const String kInstallationIdPrefKey = 'installation_id';

/// Resuelve y persiste el `installation_id` real del terminal.
///
/// El `installation_id` (terminal id de 8 caracteres) NO debe ser un valor
/// mockeado/hardcodeado en la app: se obtiene del backend vía
/// `POST /v1/terminals/resolve`, que mapea el `logical_device_id` físico del
/// terminal al `installation_id` provisionado en la central.
///
/// El `logical_device_id` se lee del hardware Verifone vía
/// [PsdkBridge.getDeviceInfo] (campo `logicalDeviceId`). Si no hay hardware
/// disponible (lab/emulador) o el bridge falla, se cae al define
/// [kLogicalDeviceId] como respaldo.
class TerminalProvisioner {
  TerminalProvisioner({http.Client? httpClient, String? baseUrl, this._psdk})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _httpClient;
  final String _baseUrl;
  final PsdkBridge? _psdk;

  /// Obtiene el `logical_device_id` del terminal.
  ///
  /// Prioriza la lectura real del hardware vía [PsdkBridge]: primero
  /// [PsdkBridge.initialize] (el SDK debe estar creado para que
  /// `getDeviceInfo` devuelva datos) y luego [PsdkBridge.getDeviceInfo]
  /// (campo `logicalDeviceId`). Si no hay bridge, no hay hardware, o la lectura
  /// falla, devuelve el define [kLogicalDeviceId] como respaldo de lab.
  Future<String> _resolveLogicalDeviceId() async {
    final psdk = _psdk;
    if (psdk != null) {
      try {
        await psdk.initialize().timeout(const Duration(seconds: 5));
        final info = await psdk.getDeviceInfo().timeout(
          const Duration(seconds: 5),
        );
        final ok = info['ok'] == true;
        final deviceId = info['logicalDeviceId'];
        if (ok && deviceId is String && deviceId.trim().isNotEmpty) {
          return deviceId.trim();
        }
      } catch (_) {
        // Bridge no disponible, timeout o error de canal: caer al define de lab.
      }
    }
    return kLogicalDeviceId;
  }

  /// Llama al backend para resolver el `installation_id` a partir del
  /// `logical_device_id` y lo persiste en SharedPreferences.
  ///
  /// Devuelve el `installation_id` resuelto, o `null` si no se pudo resolver
  /// (terminal no provisionada o error de red).
  Future<String?> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(kInstallationIdPrefKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final logicalDeviceId = await _resolveLogicalDeviceId();
    final url = Uri.parse('$_baseUrl/terminals/resolve');
    try {
      final response = await _httpClient
          .post(
            url,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({'logical_device_id': logicalDeviceId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final installationId = data['installation_id'] as String?;
        if (installationId != null && installationId.isNotEmpty) {
          await prefs.setString(kInstallationIdPrefKey, installationId);
          return installationId;
        }
      }
      return null;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Devuelve el `installation_id` persistido, o `null` si aún no se resolvió.
  Future<String?> getInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(kInstallationIdPrefKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return null;
  }
}
