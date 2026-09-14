import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:solidaridad_app/psdk/psdk_bridge.dart';
import 'package:solidaridad_app/psdk/psdk_card_reader.dart';
import 'package:solidaridad_app/psdk/psdk_msr_mock.dart';

/// Doble del bridge PSDK: permite testear el ciclo del lector sin hardware.
class MockPsdkBridge extends Mock implements PsdkBridge {}

void main() {
  late MockPsdkBridge bridge;
  late PsdkCardReader reader;

  setUp(() {
    bridge = MockPsdkBridge();
    reader = PsdkCardReader(psdk: bridge);
  });

  void stubInitialize() {
    when(
      () => bridge.initialize(),
    ).thenAnswer((_) async => <String, dynamic>{});
  }

  void stubReadyStatus() {
    when(
      () => bridge.getStatus(),
    ).thenAnswer((_) async => <String, dynamic>{'sdiReady': true});
  }

  group('PsdkCardReader.readCard', () {
    test(
      'éxito: devuelve CardReadSuccess con PAN y vencimiento MMYY',
      () async {
        stubInitialize();
        stubReadyStatus();
        when(
          () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
        ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());

        final CardReadResult result = await reader.readCard();

        expect(result, isA<CardReadSuccess>());
        final data = (result as CardReadSuccess).data;
        expect(data.pan, PsdkMsrMock.pan);
        // "3012" (YYMM) → "1230" (MMYY) para la API.
        expect(data.expiryMmYy, '1230');
      },
    );

    test('sin datos claros: CardReadFailure(unreadable)', () async {
      stubInitialize();
      stubReadyStatus();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'hasClearData': false,
          'timedOut': false,
        },
      );

      final result = await reader.readCard();

      expect(
        (result as CardReadFailure).reason,
        CardReadFailureReason.unreadable,
      );
    });

    test('timeout de lectura: CardReadFailure(timedOut)', () async {
      stubInitialize();
      stubReadyStatus();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer(
        (_) async => <String, dynamic>{'hasClearData': false, 'timedOut': true},
      );

      final result = await reader.readCard();

      expect(
        (result as CardReadFailure).reason,
        CardReadFailureReason.timedOut,
      );
    });

    test('PAN vacío: CardReadFailure(badPan)', () async {
      stubInitialize();
      stubReadyStatus();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'hasClearData': true,
          'timedOut': false,
          'tags': <String, dynamic>{},
          'msr': <String, dynamic>{},
        },
      );

      final result = await reader.readCard();

      expect((result as CardReadFailure).reason, CardReadFailureReason.badPan);
    });

    test('initialize lanza: CardReadFailure(exception)', () async {
      when(() => bridge.initialize()).thenThrow(Exception('boom'));

      final result = await reader.readCard();

      expect(
        (result as CardReadFailure).reason,
        CardReadFailureReason.exception,
      );
    });

    test('SDK no listo a tiempo: CardReadFailure(notReady)', () async {
      stubInitialize();
      when(
        () => bridge.getStatus(),
      ).thenAnswer((_) async => <String, dynamic>{});
      when(() => bridge.statusEvents).thenAnswer((_) => const Stream.empty());

      final result = await reader.readCard(readyTimeoutSec: 1);

      expect(
        (result as CardReadFailure).reason,
        CardReadFailureReason.notReady,
      );
      verifyNever(() => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')));
    });
  });

  group('PsdkCardReader.ensureReady', () {
    test('no escucha el stream si getStatus ya reporta listo', () async {
      when(
        () => bridge.getStatus(),
      ).thenAnswer((_) async => <String, dynamic>{'initialized': true});

      expect(await reader.ensureReady(), isTrue);
      verifyNever(() => bridge.statusEvents);
    });

    test('espera el stream y completa con el evento sdiReady', () async {
      when(
        () => bridge.getStatus(),
      ).thenAnswer((_) async => <String, dynamic>{});
      final controller = StreamController<Map<String, dynamic>>();
      when(() => bridge.statusEvents).thenAnswer((_) => controller.stream);

      final future = reader.ensureReady(timeoutSec: 2);
      controller.add(<String, dynamic>{'sdiReady': true});
      await controller.close();

      expect(await future, isTrue);
    });
  });

  group('PsdkCardReader.cancel', () {
    test('cancela la lectura antes de apagar el SDK (orden)', () async {
      when(
        () => bridge.cancelReadMsr(),
      ).thenAnswer((_) async => <String, dynamic>{'ok': true});
      when(
        () => bridge.tearDown(),
      ).thenAnswer((_) async => <String, dynamic>{});

      await reader.cancel();

      verifyInOrder([() => bridge.cancelReadMsr(), () => bridge.tearDown()]);
    });
  });
}
