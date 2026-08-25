import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:solidaridad_app/core/terminal/terminal_provisioner.dart';
import 'package:solidaridad_app/psdk/psdk_bridge.dart';

import 'helpers/mock_http_client.dart';

class MockPsdkBridge extends Mock implements PsdkBridge {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerHttpClientFallback();
  });

  group('TerminalProvisioner.resolve', () {
    test(
      'resuelve y persiste el installation_id real desde el backend',
      () async {
        final client = MockHttpClient();
        when(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => jsonMapResponse({'installation_id': '05000001'}),
        );

        final provisioner = TerminalProvisioner(
          httpClient: client,
          baseUrl: 'http://localhost:8000/v1',
        );

        final installationId = await provisioner.resolve();

        expect(installationId, '05000001');

        // El request envió el logical_device_id del terminal (fallback de lab).
        verify(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).called(1);

        // Persistido: un segundo resolve no vuelve a llamar al backend.
        final cached = await provisioner.getInstallationId();
        expect(cached, '05000001');
      },
    );

    test('lee el logical_device_id real del hardware vía PsdkBridge', () async {
      final client = MockHttpClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => jsonMapResponse({'installation_id': '05000002'}),
      );

      final psdk = MockPsdkBridge();
      when(
        () => psdk.initialize(),
      ).thenAnswer((_) async => {'ok': true, 'sdiReady': false});
      when(() => psdk.getDeviceInfo()).thenAnswer(
        (_) async => {
          'ok': true,
          'serialNumber': 'SN-1234',
          'logicalDeviceId': 'V660P-REAL-0002',
        },
      );

      final provisioner = TerminalProvisioner(
        httpClient: client,
        baseUrl: 'http://localhost:8000/v1',
        psdk: psdk,
      );

      final installationId = await provisioner.resolve();

      expect(installationId, '05000002');

      // El request envió el logical_device_id leído del hardware.
      final captured = verify(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;
      expect(captured, isNotEmpty);
      expect(captured.first, contains('V660P-REAL-0002'));
    });

    test(
      'cae al define de lab si el bridge no tiene hardware (ok: false)',
      () async {
        final client = MockHttpClient();
        when(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => jsonMapResponse({'installation_id': '05000001'}),
        );

        final psdk = MockPsdkBridge();
        when(
          () => psdk.initialize(),
        ).thenAnswer((_) async => {'ok': true, 'sdiReady': false});
        when(
          () => psdk.getDeviceInfo(),
        ).thenAnswer((_) async => {'ok': false, 'message': 'SDK not created'});

        final provisioner = TerminalProvisioner(
          httpClient: client,
          baseUrl: 'http://localhost:8000/v1',
          psdk: psdk,
        );

        final installationId = await provisioner.resolve();

        expect(installationId, '05000001');

        final captured = verify(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        expect(captured.first, contains(kLogicalDeviceId));
      },
    );

    test(
      'cae al define de lab si initialize() no deja el SDK listo (ok: false)',
      () async {
        final client = MockHttpClient();
        when(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => jsonMapResponse({'installation_id': '05000001'}),
        );

        final psdk = MockPsdkBridge();
        when(
          () => psdk.initialize(),
        ).thenAnswer((_) async => {'ok': false, 'message': 'init failed'});

        final provisioner = TerminalProvisioner(
          httpClient: client,
          baseUrl: 'http://localhost:8000/v1',
          psdk: psdk,
        );

        final installationId = await provisioner.resolve();

        expect(installationId, '05000001');

        final captured = verify(
          () => client.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        expect(captured.first, contains(kLogicalDeviceId));
      },
    );

    test('devuelve null si el backend no provisiona la terminal', () async {
      final client = MockHttpClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final provisioner = TerminalProvisioner(
        httpClient: client,
        baseUrl: 'http://localhost:8000/v1',
      );

      final installationId = await provisioner.resolve();
      expect(installationId, isNull);
      expect(await provisioner.getInstallationId(), isNull);
    });

    test('devuelve null ante error de red', () async {
      final client = MockHttpClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('network down'));

      final provisioner = TerminalProvisioner(
        httpClient: client,
        baseUrl: 'http://localhost:8000/v1',
      );

      final installationId = await provisioner.resolve();
      expect(installationId, isNull);
    });
  });

  group('TerminalProvisioner.getInstallationId', () {
    test('devuelve null si aún no se resolvió', () async {
      final provisioner = TerminalProvisioner(
        httpClient: MockHttpClient(),
        baseUrl: 'http://localhost:8000/v1',
      );
      expect(await provisioner.getInstallationId(), isNull);
    });
  });
}
