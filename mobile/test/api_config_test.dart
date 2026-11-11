import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/core/config/api_config.dart';

void main() {
  ApiConfigResolution resolve({
    String fromDefine = '',
    bool releaseMode = false,
    bool isWeb = false,
    bool isAndroid = false,
  }) {
    return ApiConfig.resolve(
      fromDefine: fromDefine,
      releaseMode: releaseMode,
      isWeb: isWeb,
      isAndroid: isAndroid,
    );
  }

  test('release sin URL no llama a la red', () {
    final decision = resolve(releaseMode: true);

    expect(decision.isOk, isFalse);
    expect(decision.baseUrl, isNull);
    expect(decision.error, ApiConfig.releaseMissingUrlError);
  });

  test('release con HTTP no llama a la red', () {
    final decision = resolve(
      releaseMode: true,
      fromDefine: 'http://api.example/v1',
    );

    expect(decision.isOk, isFalse);
    expect(decision.baseUrl, isNull);
    expect(decision.error, ApiConfig.releaseHttpError);
  });

  test('release con https usa esa URL', () {
    final decision = resolve(
      releaseMode: true,
      fromDefine: ' https://api.example/v1 ',
    );

    expect(decision.isOk, isTrue);
    expect(decision.error, isNull);
    expect(decision.baseUrl, 'https://api.example/v1');
  });

  test('debug Android sin URL sigue en el emulador', () {
    final decision = resolve(isAndroid: true);

    expect(decision.baseUrl, ApiConfig.labAndroidBaseUrl);
    expect(decision.error, isNull);
  });

  test('debug web sin URL sigue en localhost', () {
    final decision = resolve(isWeb: true);

    expect(decision.baseUrl, ApiConfig.labLocalBaseUrl);
    expect(decision.error, isNull);
  });

  test('un define no vacío gana sobre el default de laboratorio', () {
    final decision = resolve(
      isAndroid: true,
      fromDefine: 'http://192.168.1.42:8000/v1',
    );

    expect(decision.baseUrl, 'http://192.168.1.42:8000/v1');
    expect(decision.error, isNull);
  });

  test('release con solo espacios es lo mismo que sin URL', () {
    final decision = resolve(releaseMode: true, fromDefine: '   ');

    expect(decision.isOk, isFalse);
    expect(decision.baseUrl, isNull);
    expect(decision.error, ApiConfig.releaseMissingUrlError);
  });

  test('release con HTTP en mayúsculas no llama a la red', () {
    final decision = resolve(
      releaseMode: true,
      fromDefine: 'HTTP://api.example/v1',
    );

    expect(decision.isOk, isFalse);
    expect(decision.baseUrl, isNull);
    expect(decision.error, ApiConfig.releaseHttpError);
  });

  test('release con HTTPS en mayúsculas conserva la URL sin espacios', () {
    final decision = resolve(
      releaseMode: true,
      fromDefine: ' HTTPS://api.example/v1 ',
    );

    expect(decision.isOk, isTrue);
    expect(decision.error, isNull);
    expect(decision.baseUrl, 'HTTPS://api.example/v1');
  });

  test('release rechaza un esquema que no es https://', () {
    final missingSlash = resolve(
      releaseMode: true,
      fromDefine: 'https:api.example',
    );
    final ftp = resolve(releaseMode: true, fromDefine: 'ftp://api.example/v1');

    expect(missingSlash.error, ApiConfig.releaseHttpError);
    expect(missingSlash.baseUrl, isNull);
    expect(ftp.error, ApiConfig.releaseHttpError);
    expect(ftp.baseUrl, isNull);
  });

  test('release en Android usa la URL https y no el emulador', () {
    final decision = resolve(
      releaseMode: true,
      isAndroid: true,
      fromDefine: 'https://api.example/v1',
    );

    expect(decision.baseUrl, 'https://api.example/v1');
    expect(decision.baseUrl, isNot(ApiConfig.labAndroidBaseUrl));
    expect(decision.error, isNull);
  });

  test('debug de iOS o escritorio sin URL usa localhost', () {
    final decision = resolve();

    expect(decision.baseUrl, ApiConfig.labLocalBaseUrl);
    expect(decision.error, isNull);
  });

  test('debug con define en blanco usa el default de laboratorio', () {
    final decision = resolve(isAndroid: true, fromDefine: '   ');

    expect(decision.baseUrl, ApiConfig.labAndroidBaseUrl);
    expect(decision.error, isNull);
  });
}
