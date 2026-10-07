import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/core/device/device_identity_service.dart';
import 'package:solidaridad_app/psdk/psdk_bridge.dart';

class MockPsdkBridge extends Mock implements PsdkBridge {}

void main() {
  group('DeviceIdentityService', () {
    late MockPsdkBridge bridge;

    setUp(() {
      bridge = MockPsdkBridge();
    });

    test('devuelve solo installationId cuando no se lee hardware', () async {
      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: false,
      );

      final identity = await service.resolve();

      expect(identity.installationId, '05000001');
      expect(identity.serialNumber, isNull);
      expect(identity.logicalDeviceId, isNull);
      expect(identity.hasHardwareInfo, isFalse);
      verifyZeroInteractions(bridge);
    });

    test('parsea serial y logical cuando el SDK ya está listo', () async {
      when(() => bridge.getStatus()).thenAnswer(
        (_) async => {'created': true, 'sdiReady': true},
      );
      when(() => bridge.getDeviceInfo()).thenAnswer(
        (_) async => {
          'ok': true,
          'serialNumber': '713-348-525',
          'logicalDeviceId': 'lab-0001',
        },
      );

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final identity = await service.resolve();

      expect(identity.installationId, '05000001');
      expect(identity.serialNumber, '713-348-525');
      expect(identity.logicalDeviceId, 'lab-0001');
      expect(identity.hasHardwareInfo, isTrue);
      verify(() => bridge.getDeviceInfo()).called(1);
    });

    test('inicializa y espera sdiReady antes de leer device info', () async {
      when(() => bridge.getStatus()).thenAnswer(
        (_) async => {'created': true, 'sdiReady': false},
      );
      when(() => bridge.initialize()).thenAnswer(
        (_) async => {'ok': true, 'sdiReady': false},
      );
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      when(() => bridge.statusEvents).thenAnswer((_) => controller.stream);
      when(() => bridge.getDeviceInfo()).thenAnswer(
        (_) async => {
          'ok': true,
          'serialNumber': '713-348-525',
          'logicalDeviceId': 'lab-0001',
        },
      );

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final future = service.resolve();
      await Future<void>.delayed(Duration.zero);
      controller.add({'sdiReady': true, 'success': true});
      final identity = await future;
      await controller.close();

      expect(identity.serialNumber, '713-348-525');
      expect(identity.logicalDeviceId, 'lab-0001');
      verify(() => bridge.initialize()).called(1);
    });

    test('degrada sin hardware cuando getDeviceInfo falla', () async {
      when(() => bridge.getStatus()).thenAnswer(
        (_) async => {'created': true, 'sdiReady': true},
      );
      when(() => bridge.getDeviceInfo()).thenAnswer(
        (_) async => {'ok': false, 'message': 'deviceInformation is null'},
      );

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final identity = await service.resolve();

      expect(identity.installationId, '05000001');
      expect(identity.serialNumber, isNull);
      expect(identity.logicalDeviceId, isNull);
    });

    test('degrada sin hardware cuando el SDK lanza', () async {
      when(() => bridge.getStatus()).thenThrow(Exception('boom'));

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final identity = await service.resolve();

      expect(identity.installationId, '05000001');
      expect(identity.hasHardwareInfo, isFalse);
    });

    test('trata vacío y "*" como sin dato de hardware', () async {
      when(() => bridge.getStatus()).thenAnswer(
        (_) async => {'created': true, 'sdiReady': true},
      );
      when(() => bridge.getDeviceInfo()).thenAnswer(
        (_) async => {
          'ok': true,
          'serialNumber': '',
          'logicalDeviceId': '*',
        },
      );

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final identity = await service.resolve();

      expect(identity.serialNumber, isNull);
      expect(identity.logicalDeviceId, isNull);
      expect(identity.hasHardwareInfo, isFalse);
    });

    test('cachea la identidad y no vuelve a tocar el SDK', () async {
      when(() => bridge.getStatus()).thenAnswer(
        (_) async => {'created': true, 'sdiReady': true},
      );
      when(() => bridge.getDeviceInfo()).thenAnswer(
        (_) async => {
          'ok': true,
          'serialNumber': '713-348-525',
          'logicalDeviceId': 'lab-0001',
        },
      );

      final service = DeviceIdentityService(
        psdk: bridge,
        installationId: '05000001',
        readHardware: true,
      );

      final first = await service.resolve();
      final second = await service.resolve();

      expect(identical(first, second), isTrue);
      verify(() => bridge.getDeviceInfo()).called(1);
    });
  });
}