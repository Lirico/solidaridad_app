import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/psdk/psdk_bridge.dart';
import 'package:solidaridad_app/psdk/psdk_card_reader.dart';
import 'package:solidaridad_app/psdk/psdk_msr_mock.dart';

class MockPsdkBridge extends Mock implements PsdkBridge {}

void main() {
  late MockPsdkBridge bridge;
  late PsdkCardReader reader;
  setUp(() {
    bridge = MockPsdkBridge();
    reader = PsdkCardReader(psdk: bridge);
    when(() => bridge.initialize()).thenAnswer((_) async => {'ok': true});
    when(() => bridge.tearDown()).thenAnswer((_) async => {'ok': true});
    when(() => bridge.cancelReadMsr()).thenAnswer((_) async => {'ok': true});
    when(() => bridge.getStatus()).thenAnswer((_) async => {'sdiReady': true});
  });

  test('una lectura exitosa conserva la sesión para la impresora', () async {
    when(
      () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
    ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());
    expect(await reader.readCard(), isA<CardReadSuccess>());
    verifyNever(() => bridge.tearDown());
    verifyNever(() => bridge.cancelReadMsr());
    await reader.cancel();
    verifyNever(() => bridge.cancelReadMsr());
  });

  test('una lectura sin datos informa el error sin cerrar la sesión', () async {
    when(
      () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
    ).thenAnswer((_) async => {'hasClearData': false});
    final result = await reader.readCard() as CardReadFailure;
    expect(result.reason, CardReadFailureReason.unreadable);
    verifyNever(() => bridge.tearDown());
  });

  test('el timeout y el PAN vacío conservan su motivo', () async {
    when(
      () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
    ).thenAnswer((_) async => {'hasClearData': false, 'timedOut': true});
    expect(
      (await reader.readCard() as CardReadFailure).reason,
      CardReadFailureReason.timedOut,
    );
    when(() => bridge.readMsr(timeoutSec: any(named: 'timeoutSec'))).thenAnswer(
      (_) async => {
        'hasClearData': true,
        'msr': <String, dynamic>{},
        'tags': <String, dynamic>{},
      },
    );
    expect(
      (await reader.readCard() as CardReadFailure).reason,
      CardReadFailureReason.badPan,
    );
    verifyNever(() => bridge.tearDown());
  });

  test(
    'cancelaciones simultáneas esperan una sola solicitud de abort',
    () async {
      final read = Completer<Map<String, dynamic>>();
      final cancel = Completer<Map<String, dynamic>>();
      when(
        () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
      ).thenAnswer((_) => read.future);
      when(() => bridge.cancelReadMsr()).thenAnswer((_) => cancel.future);
      final reading = reader.readCard();
      await pumpEventQueue();
      final first = reader.cancel();
      final second = reader.cancel();
      read.complete({'cancelled': true});
      cancel.complete({'ok': true});
      await Future.wait([first, second]);
      expect(await reading, isA<CardReadFailure>());
      verify(() => bridge.cancelReadMsr()).called(1);
      verifyNever(() => bridge.tearDown());
    },
  );

  test('fallo de arranque espera cierre antes de reintentar', () async {
    var calls = 0;
    when(
      () => bridge.getStatus(),
    ).thenAnswer((_) async => {'sdiReady': ++calls > 2});
    when(() => bridge.statusEvents).thenAnswer((_) => const Stream.empty());
    final close = Completer<Map<String, dynamic>>();
    when(() => bridge.tearDown()).thenAnswer((_) => close.future);
    when(
      () => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')),
    ).thenAnswer((_) async => PsdkMsrMock.readMsrSuccess());
    final reading = reader.readCard(
      readyTimeoutSec: 0,
      initAttempts: 2,
      initRetryDelay: Duration.zero,
    );
    await pumpEventQueue();
    verify(() => bridge.initialize()).called(1);
    verifyNever(() => bridge.readMsr(timeoutSec: any(named: 'timeoutSec')));
    close.complete({'ok': true});
    expect(await reading, isA<CardReadSuccess>());
    verify(() => bridge.initialize()).called(1);
  });

  test('un success sin sdiReady no habilita operaciones', () async {
    when(() => bridge.getStatus()).thenAnswer((_) async => {});
    when(
      () => bridge.statusEvents,
    ).thenAnswer((_) => Stream.value({'success': true, 'sdiReady': false}));
    expect(await reader.ensureReady(timeoutSec: 0), isFalse);
  });
}
