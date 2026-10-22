import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidaridad_app/core/terminal/terminal_id_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesTerminalIdStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    store = SharedPreferencesTerminalIdStore(preferences: preferences);
  });

  test('sin valor guardado, la lectura es nula', () async {
    expect(await store.read(), isNull);
  });

  test('guarda un código válido recortando espacios', () async {
    expect(await store.save('  05000002  '), '05000002');
    expect(await store.read(), '05000002');
  });

  test('rechaza un código de más de 8 caracteres y no lo escribe', () async {
    expect(await store.save('123456789'), isNull);
    expect(await store.read(), isNull);
  });

  test('rechaza un valor de solo espacios', () async {
    expect(await store.save('   '), isNull);
    expect(await store.read(), isNull);
  });

  test('un guardado inválido no pisa un código ya válido', () async {
    await store.save('05000001');
    expect(await store.save('123456789'), isNull);
    expect(await store.read(), '05000001');
  });

  test('un valor guardado inválido se lee como sin configurar', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesTerminalIdStore.storageKey: '123456789',
    });
    final preferences = await SharedPreferences.getInstance();
    final corrupt = SharedPreferencesTerminalIdStore(preferences: preferences);

    expect(await corrupt.read(), isNull);
  });
}
