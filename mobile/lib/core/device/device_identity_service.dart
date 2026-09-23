import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../psdk/psdk_bridge.dart';
import 'device_identity.dart';

/// Resuelve la identidad de la terminal (`installation_id` + hardware).
///
/// La lectura del hardware es *best-effort*: si el PSDK no está disponible
/// (emulador/lab/Windows/web), si inicializar falla o si `getDeviceInfo()` no
/// responde, el servicio degrada a una identidad con solo [installationId] y
/// **nunca lanza**. Así el login nunca se rompe por culpa de estos datos.
class DeviceIdentityService {
  DeviceIdentityService({
    PsdkBridge? psdk,
    String? installationId,
    bool? readHardware,
  })  : _psdk = psdk ?? PsdkBridge(),
        _installationIdOverride = installationId,
        _readHardware = readHardware ?? _canReadHardware();

  final PsdkBridge _psdk;
  final String? _installationIdOverride;
  final bool _readHardware;

  /// Tiempo máximo que esperamos al SDK para leer serial/logical.
  static const Duration hardwareReadTimeout = Duration(seconds: 4);

  DeviceIdentity? _cached;

  /// Código de negocio de la instalación/terminal.
  ///
  /// Origen: `--dart-define=INSTALLATION_ID=...` o el default de demo.
  String get installationId {
    final override = _installationIdOverride;
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    const fromDefine = String.fromEnvironment(
      'INSTALLATION_ID',
      defaultValue: '05000001',
    );
    return fromDefine;
  }

  /// Devuelve la identidad de la terminal.
  ///
  /// La primera llamada intenta leer el hardware (best-effort) y cachea el
  /// resultado en memoria; las siguientes devuelven la caché.
  Future<DeviceIdentity> resolve() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }
    final identity = await _resolveFresh();
    _cached = identity;
    return identity;
  }

  Future<DeviceIdentity> _resolveFresh() async {
    String? serialNumber;
    String? logicalDeviceId;

    if (_readHardware) {
      try {
        final info = await _readDeviceInfo().timeout(hardwareReadTimeout);
        if (info['ok'] == true) {
          serialNumber = _nonEmpty(info['serialNumber']);
          logicalDeviceId = _nonEmpty(info['logicalDeviceId']);
        }
      } catch (_) {
        // Best-effort: degradar a identidad sin hardware.
      }
    }

    return DeviceIdentity(
      installationId: installationId,
      serialNumber: serialNumber,
      logicalDeviceId: logicalDeviceId,
    );
  }

  Future<Map<String, dynamic>> _readDeviceInfo() async {
    final status = await _psdk.getStatus();
    if (status['sdiReady'] != true) {
      await _psdk.initialize();
      await _waitForSdkReady();
    }
    return _psdk.getDeviceInfo();
  }

  /// Espera el evento `sdiReady` del PSDK tras [PsdkBridge.initialize].
  ///
  /// Replica el patrón de `ReceiptPrinter._ensureSdkReady`: `initialize()` es
  /// asíncrono y el SDK recién queda listo cuando llega `handleStatus` con
  /// SUCCESS por el stream de eventos.
  Future<void> _waitForSdkReady() async {
    final completer = Completer<void>();
    StreamSubscription<Map<String, dynamic>>? sub;

    sub = _psdk.statusEvents.listen((event) {
      final ready = event['sdiReady'] == true || event['success'] == true;
      if (ready && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future.timeout(hardwareReadTimeout);
    } finally {
      await sub.cancel();
    }
  }

  /// Placeholder que el PSDK usa cuando un campo no tiene valor asignado.
  static const String noValuePlaceholder = '*';

  static String? _nonEmpty(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == noValuePlaceholder) {
      return null;
    }
    return trimmed;
  }

  static bool _canReadHardware() {
    return !kIsWeb && (Platform.isAndroid || kUseMsrMock);
  }
}