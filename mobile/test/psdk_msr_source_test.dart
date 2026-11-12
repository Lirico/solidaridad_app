import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/psdk/psdk_msr_source.dart';

void main() {
  test('sin el flag no hay lectura de laboratorio', () {
    expect(labMsrEnabled(useMock: false, releaseMode: false), isFalse);
    expect(labMsrEnabled(useMock: false, releaseMode: true), isFalse);
  });

  test('un release con el flag no devuelve la tarjeta', () {
    expect(
      () => labMsrEnabled(useMock: true, releaseMode: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          releaseMsrMockError,
        ),
      ),
    );
  });

  test('el laboratorio con el flag devuelve el fixture', () {
    expect(labMsrEnabled(useMock: true, releaseMode: false), isTrue);
    final payload = labReadMsr(timeoutSec: 12);
    expect(payload['mocked'], isTrue);
    expect(payload['timeoutSec'], 12);
    expect(payload['tags'], isA<Map<String, dynamic>>());
  });
}
