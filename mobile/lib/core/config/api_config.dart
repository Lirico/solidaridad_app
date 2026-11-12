import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Resultado de elegir la URL de la API.
///
/// [baseUrl] está presente cuando la app puede llamar a la red.
/// [error] está presente cuando un release no tiene una URL `https`.
class ApiConfigResolution {
  const ApiConfigResolution._({this.baseUrl, this.error});

  final String? baseUrl;
  final String? error;

  bool get isOk => error == null && baseUrl != null;
}

/// Configuración de la conexión con la API.
///
/// La URL se pasa en el build con `--dart-define=API_BASE_URL=...`.
///
/// Sin ese define:
/// - **Release:** no hay default. La app no llama a la red.
/// - **Debug y profile:** web y escritorio usan `localhost`; Android usa
///   `10.0.2.2`, que es el loopback del emulador.
///
/// Un release además exige que la URL empiece con `https://`.
class ApiConfig {
  ApiConfig._();

  static const String labAndroidBaseUrl = 'http://10.0.2.2:8000/v1';
  static const String labLocalBaseUrl = 'http://localhost:8000/v1';

  static const String releaseMissingUrlError =
      'Este APK de release no tiene servidor. '
      'Recompilá con --dart-define=API_BASE_URL=https://<servidor>/v1';

  static const String releaseHttpError =
      'Este APK de release no puede usar HTTP. '
      'Recompilá con --dart-define=API_BASE_URL=https://<servidor>/v1';

  static const String releaseInvalidUrlError =
      'Este APK de release no tiene una URL HTTPS válida. '
      'Recompilá con --dart-define=API_BASE_URL=https://<servidor>/v1';

  static ApiConfigResolution resolve({
    required String fromDefine,
    required bool releaseMode,
    required bool isWeb,
    required bool isAndroid,
  }) {
    final configured = fromDefine.trim();
    if (releaseMode) {
      if (configured.isEmpty) {
        return const ApiConfigResolution._(error: releaseMissingUrlError);
      }
      final uri = Uri.tryParse(configured);
      if (uri == null) {
        return const ApiConfigResolution._(error: releaseInvalidUrlError);
      }
      if (uri.scheme.toLowerCase() != 'https') {
        return const ApiConfigResolution._(error: releaseHttpError);
      }
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        return const ApiConfigResolution._(error: releaseInvalidUrlError);
      }
      return ApiConfigResolution._(baseUrl: _withoutTrailingSlash(configured));
    }

    if (configured.isNotEmpty) {
      return ApiConfigResolution._(baseUrl: configured);
    }
    if (isWeb) {
      return const ApiConfigResolution._(baseUrl: labLocalBaseUrl);
    }
    if (isAndroid) {
      return const ApiConfigResolution._(baseUrl: labAndroidBaseUrl);
    }
    return const ApiConfigResolution._(baseUrl: labLocalBaseUrl);
  }

  static ApiConfigResolution get resolution {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (kIsWeb) {
      return resolve(
        fromDefine: fromDefine,
        releaseMode: kReleaseMode,
        isWeb: true,
        isAndroid: false,
      );
    }
    return resolve(
      fromDefine: fromDefine,
      releaseMode: kReleaseMode,
      isWeb: false,
      isAndroid: Platform.isAndroid,
    );
  }

  /// URL lista para llamar. Falla si el release no está configurado:
  /// en ese caso hay que usar [resolution] y no abrir la red.
  static String get baseUrl {
    final decision = resolution;
    final url = decision.baseUrl;
    if (url == null) {
      throw StateError(decision.error ?? releaseMissingUrlError);
    }
    return url;
  }

  static String _withoutTrailingSlash(String url) {
    return url.replaceFirst(RegExp(r'/+$'), '');
  }
}
