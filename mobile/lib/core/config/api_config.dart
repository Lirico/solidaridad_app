import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration for the API connection.
///
/// The base URL can be overridden at build time via `--dart-define=API_BASE_URL=...`.
/// Detection logic (only applies when no `--dart-define` is set):
/// - **Web**: uses `localhost`
/// - **Android emulator**: uses `10.0.2.2` (Android host loopback)
/// - **Android real device / iOS**: uses `localhost`
///
/// For a real device on the same WiFi network, you MUST pass
/// `--dart-define=API_BASE_URL=http://<YOUR_PC_IP>:8000/v1` at build time.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }

    if (kIsWeb) {
      return 'http://localhost:8000/v1';
    }

    // Android / iOS / others
    if (Platform.isAndroid) {
      // 10.0.2.2 is the Android emulator's alias for the host machine
      return 'http://10.0.2.2:8000/v1';
    }

    // iOS simulator / others
    return 'http://localhost:8000/v1';
  }
}
