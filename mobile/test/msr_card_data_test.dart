import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/psdk/msr_card_data.dart';

void main() {
  MsrCardData read({String expiry = '', required String track2}) {
    return MsrCardData.fromBridge(<String, dynamic>{
      'tags': <String, dynamic>{
        'pan': '6063007014007403',
        'expiry': expiry,
        'track2': track2,
      },
      'msr': <String, dynamic>{},
    });
  }

  test('toma el vencimiento aunque el service code siga pegado', () {
    final data = read(track2: ';6063007014007403=3012101?');
    expect(data.expiryYyMm, '3012');
    expect(data.expiryMmYy, '1230');
  });

  test(
    'sigue leyendo el formato corto con el ? justo después del vencimiento',
    () {
      final data = read(track2: ';6063007014007403=3012?8');
      expect(data.expiryYyMm, '3012');
    },
  );

  test('sin separador, toma los 4 dígitos que siguen al PAN', () {
    final data = read(track2: '60630070140074033012101?');
    expect(data.expiryYyMm, '3012');
    expect(data.expiryMmYy, '1230');
  });

  test('si el = no deja 4 dígitos, toma los 4 que siguen al PAN', () {
    final data = read(track2: '60630070140074033012101=');
    expect(data.expiryYyMm, '3012');
    expect(data.expiryMmYy, '1230');
  });

  test('sin separador y sin 4 dígitos después del PAN, queda vacío', () {
    final data = read(track2: '606300701400740330');
    expect(data.expiryYyMm, isEmpty);
  });

  test('si el tag de vencimiento viene, no usa el track2', () {
    final data = read(expiry: '2812', track2: ';6063007014007403=3012101?');
    expect(data.expiryYyMm, '2812');
  });

  test('sin vencimiento en el tag ni en la pista, queda vacío', () {
    final data = read(track2: ';6063007014007403=?');
    expect(data.expiryYyMm, isEmpty);
    expect(data.expiryMmYy, isEmpty);
  });
}
