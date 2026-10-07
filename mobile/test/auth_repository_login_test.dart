import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/core/device/device_identity.dart';
import 'package:solidaridad_app/core/device/device_identity_service.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';

import 'helpers/mock_http_client.dart';

class MockDeviceIdentityService extends Mock implements DeviceIdentityService {}

void main() {
  group('AuthRepository.login', () {
    late MockHttpClient client;
    late MockDeviceIdentityService deviceIdentity;

    final Uri loginUrl = Uri.parse('http://api.test/auth/login');

    setUp(() {
      client = MockHttpClient();
      deviceIdentity = MockDeviceIdentityService();
      registerHttpClientFallback();
    });

    void stubSuccessPost() {
      when(
        () => client.post(
          loginUrl,
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => jsonMapResponse({
          'name': 'Demo',
          'email': 'demo@solidaridad.local',
          'token': 'token-123',
          'must_change_password': false,
        }),
      );
    }

    AuthRepository buildRepo() {
      return AuthRepository(
        httpClient: client,
        baseUrl: 'http://api.test',
        deviceIdentity: deviceIdentity,
      );
    }

    test('envía installation_id + serial/logical cuando hay hardware', () async {
      when(() => deviceIdentity.resolve()).thenAnswer(
        (_) async => const DeviceIdentity(
          installationId: '05000001',
          serialNumber: '713-348-525',
          logicalDeviceId: 'lab-0001',
        ),
      );
      stubSuccessPost();

      final response = await buildRepo().login(
        usernameOrEmail: 'demo@solidaridad.local',
        password: 'demo1234',
      );

      expect(response.isSuccess, isTrue);
      final captured = verify(
        () => client.post(
          loginUrl,
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body['installation_id'], '05000001');
      expect(body['serial_number'], '713-348-525');
      expect(body['logical_device_id'], 'lab-0001');
    });

    test('envía serial/logical como "" cuando no hay hardware', () async {
      when(() => deviceIdentity.resolve()).thenAnswer(
        (_) async => const DeviceIdentity(installationId: '05000001'),
      );
      stubSuccessPost();

      await buildRepo().login(
        usernameOrEmail: 'demo@solidaridad.local',
        password: 'demo1234',
      );

      final captured = verify(
        () => client.post(
          loginUrl,
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body['installation_id'], '05000001');
      expect(body['serial_number'], '');
      expect(body['logical_device_id'], '');
    });
  });
}