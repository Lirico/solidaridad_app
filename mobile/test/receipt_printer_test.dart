import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/sales/data/receipt_printer.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/psdk/psdk_bridge.dart';

class MockPsdkBridge extends Mock implements PsdkBridge {}

OperationModel _operation() {
  return OperationModel(
    id: 'OP-1',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
    cardNumber: '6063007014007403',
    result: PaymentResult.approved,
    date: DateTime(2026, 10, 23, 12),
  );
}

void main() {
  late MockPsdkBridge bridge;
  late ReceiptPrinter printer;

  setUp(() {
    bridge = MockPsdkBridge();
    printer = ReceiptPrinter(psdk: bridge);
    when(
      () => bridge.initialize(),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(() => bridge.tearDown()).thenAnswer((_) async => <String, dynamic>{});
    when(() => bridge.getStatus()).thenAnswer((_) async => <String, dynamic>{});
  });

  Future<PrintResult> printWithShortStartup() {
    return printer.printTicket(
      _operation(),
      initAttempts: 2,
      initRetryDelay: Duration.zero,
      readyTimeoutSec: 1,
    );
  }

  test(
    'un success sin sdiReady se reintenta y el segundo intento imprime',
    () async {
      var listens = 0;
      when(() => bridge.statusEvents).thenAnswer((_) {
        listens += 1;
        if (listens == 1) {
          return Stream<Map<String, dynamic>>.value(<String, dynamic>{
            'success': true,
            'sdiReady': false,
          });
        }
        return Stream<Map<String, dynamic>>.value(<String, dynamic>{
          'sdiReady': true,
        });
      });
      when(
        () => bridge.printHtml(any()),
      ).thenAnswer((_) async => <String, dynamic>{'ok': true});

      final PrintResult result = await printWithShortStartup();

      expect(result.ok, isTrue);
      expect(result.message, 'Ticket impreso');
      verify(() => bridge.initialize()).called(2);
      verify(() => bridge.tearDown()).called(1);
      verify(() => bridge.printHtml(any())).called(1);
    },
  );

  test('PSDK_NOT_READY se reintenta y el segundo printHtml imprime', () async {
    when(
      () => bridge.getStatus(),
    ).thenAnswer((_) async => <String, dynamic>{'sdiReady': true});
    var prints = 0;
    when(() => bridge.printHtml(any())).thenAnswer((_) async {
      prints += 1;
      if (prints == 1) {
        throw PlatformException(
          code: 'PSDK_NOT_READY',
          message: 'SDI not ready',
        );
      }
      return <String, dynamic>{'ok': true};
    });

    final PrintResult result = await printer.printTicket(
      _operation(),
      initRetryDelay: Duration.zero,
    );

    expect(result.ok, isTrue);
    verify(() => bridge.printHtml(any())).called(2);
    verify(() => bridge.tearDown()).called(1);
    verifyNever(() => bridge.initialize());
  });

  test('agotar los intentos deja el mensaje de inicialización', () async {
    when(() => bridge.statusEvents).thenAnswer(
      (_) => Stream<Map<String, dynamic>>.value(<String, dynamic>{
        'success': true,
        'sdiReady': false,
      }),
    );

    final PrintResult result = await printWithShortStartup();

    expect(result.ok, isFalse);
    expect(result.message, 'No se pudo inicializar la impresora. Reintente.');
    verifyNever(() => bridge.printHtml(any()));
    verify(() => bridge.tearDown()).called(2);
  });

  test('un código de printHTML ya ejecutado no se reintenta', () async {
    when(
      () => bridge.getStatus(),
    ).thenAnswer((_) async => <String, dynamic>{'sdiReady': true});
    when(() => bridge.printHtml(any())).thenAnswer(
      (_) async => <String, dynamic>{'ok': false, 'result': 'ERR_PAPER'},
    );

    final PrintResult result = await printer.printTicket(_operation());

    expect(result.ok, isFalse);
    expect(result.message, 'La impresora no imprimió (código ERR_PAPER).');
    verify(() => bridge.printHtml(any())).called(1);
    verifyNever(() => bridge.tearDown());
  });
}
