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
    when(
      () => bridge.cancelReadMsr(),
    ).thenAnswer((_) async => <String, dynamic>{'ok': true});
    when(() => bridge.tearDown()).thenAnswer((_) async => <String, dynamic>{});
  });

  void verifyReleasedOnce() {
    verify(() => bridge.cancelReadMsr()).called(1);
    verify(() => bridge.tearDown()).called(1);
  }

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
        verifyReleasedOnce();
      },
    );

    test(
      'éxito: no devuelve el resultado antes de terminar el tearDown',
      () async {
        stubInitialize();
        stubReadyStatus();
        when(
          () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
        ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());
        final Completer<Map<String, dynamic>> tearDownGate = Completer();
        when(() => bridge.tearDown()).thenAnswer((_) => tearDownGate.future);

        final Future<CardReadResult> future = reader.readCard();
        var completed = false;
        future.whenComplete(() => completed = true);
        await pumpEventQueue();

        expect(completed, isFalse);
        verify(() => bridge.tearDown()).called(1);

        tearDownGate.complete(<String, dynamic>{});
        expect(await future, isA<CardReadSuccess>());
        expect(completed, isTrue);
      },
    );

    test(
      'sin datos claros: CardReadFailure(unreadable) tras el tearDown',
      () async {
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
        final Completer<Map<String, dynamic>> tearDownGate = Completer();
        when(() => bridge.tearDown()).thenAnswer((_) => tearDownGate.future);

        final Future<CardReadResult> future = reader.readCard();
        var completed = false;
        future.whenComplete(() => completed = true);
        await pumpEventQueue();

        expect(completed, isFalse);
        tearDownGate.complete(<String, dynamic>{});

        final result = await future;
        expect(
          (result as CardReadFailure).reason,
          CardReadFailureReason.unreadable,
        );
        verifyReleasedOnce();
      },
    );

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
      verifyReleasedOnce();
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
      verifyReleasedOnce();
    });

    test(
      'initialize lanza: CardReadFailure(exception) y libera el SDK',
      () async {
        when(() => bridge.initialize()).thenThrow(Exception('boom'));
        final Completer<Map<String, dynamic>> tearDownGate = Completer();
        when(() => bridge.tearDown()).thenAnswer((_) => tearDownGate.future);

        final Future<CardReadResult> future = reader.readCard();
        var completed = false;
        future.whenComplete(() => completed = true);
        await pumpEventQueue();

        expect(completed, isFalse);
        tearDownGate.complete(<String, dynamic>{});

        final result = await future;
        expect(
          (result as CardReadFailure).reason,
          CardReadFailureReason.exception,
        );
        verifyReleasedOnce();
      },
    );

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
      verifyReleasedOnce();
    });

    test(
      'notReady: no devuelve el fallo antes de terminar el tearDown',
      () async {
        stubInitialize();
        when(
          () => bridge.getStatus(),
        ).thenAnswer((_) async => <String, dynamic>{});
        when(() => bridge.statusEvents).thenAnswer((_) => const Stream.empty());
        final Completer<Map<String, dynamic>> tearDownGate = Completer();
        when(() => bridge.tearDown()).thenAnswer((_) => tearDownGate.future);

        final Future<CardReadResult> future = reader.readCard(
          readyTimeoutSec: 1,
        );
        var completed = false;
        future.whenComplete(() => completed = true);

        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(completed, isFalse);

        tearDownGate.complete(<String, dynamic>{});
        expect(
          ((await future) as CardReadFailure).reason,
          CardReadFailureReason.notReady,
        );
      },
    );
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
    test('durante la lectura se une a una sola liberación', () async {
      stubInitialize();
      stubReadyStatus();
      final Completer<Map<String, dynamic>> readGate = Completer();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer((_) => readGate.future);
      final List<String> order = <String>[];
      when(() => bridge.cancelReadMsr()).thenAnswer((_) async {
        order.add('cancel');
        return <String, dynamic>{'ok': true};
      });
      when(() => bridge.tearDown()).thenAnswer((_) async {
        order.add('tearDown');
        return <String, dynamic>{};
      });

      final Future<CardReadResult> future = reader.readCard();
      await pumpEventQueue();

      final Future<void> cancelFuture = reader.cancel();
      readGate.complete(PsdkMsrMock.readMsrSuccess());
      await cancelFuture;
      await future;

      expect(order, ['cancel', 'tearDown']);
    });

    test('después de leer no vuelve a apagar el SDK', () async {
      stubInitialize();
      stubReadyStatus();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());

      await reader.readCard();
      clearInteractions(bridge);

      await reader.cancel();

      verifyNever(() => bridge.cancelReadMsr());
      verifyNever(() => bridge.tearDown());
    });

    test('una segunda lectura vuelve a liberar el SDK', () async {
      stubInitialize();
      stubReadyStatus();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());

      await reader.readCard();
      await reader.readCard();

      verify(() => bridge.cancelReadMsr()).called(2);
      verify(() => bridge.tearDown()).called(2);
    });
  });
}
