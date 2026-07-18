/// Configuration for the API connection.
///
/// The base URL can be overridden at build time via `--dart-define=API_BASE_URL=...`.
/// Defaults to localhost for development.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const fromDefine = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/v1',
    );
    return fromDefine;
  }
}
