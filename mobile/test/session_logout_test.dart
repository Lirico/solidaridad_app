import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/session_store.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';

class _Client extends Mock implements http.Client {}

String _jwt() {
  String part(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${part({'alg': 'none'})}.${part({'sub': '1'})}.sig';
}

void main() {
  test('logout avisa a la API antes de borrar la sesión', () async {
    final store = MemorySessionStore();
    final client = _Client();
    final token = _jwt();
    var sessionWasPresent = false;
    registerFallbackValue(Uri.parse('http://api.test'));
    when(
      () => client.post(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async {
      sessionWasPresent = (await store.read()) != null;
      return http.Response('{"message":"Sesión cerrada"}', 200);
    });
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenThrow(Exception('sin comercio'));

    await store.save(
      PersistedSession(
        user: User(name: 'Ana', email: 'ana@comercio.test', token: token),
        mustChangePassword: false,
        merchant: null,
      ),
    );
    final cubit = AuthCubit(
      authRepository: AuthRepository(
        httpClient: client,
        baseUrl: 'http://api.test',
      ),
      sessionStore: store,
    );
    await cubit.restore();
    await cubit.logout();

    expect(sessionWasPresent, isTrue);
    expect(cubit.state, isA<AuthInitial>());
    expect(await store.read(), isNull);
    final captured = verify(
      () => client.post(captureAny(), headers: captureAny(named: 'headers')),
    ).captured;
    expect(captured.first.toString(), 'http://api.test/auth/logout');
    expect(
      (captured[1] as Map<String, String>)['authorization'],
      'Bearer $token',
    );
    await cubit.close();
  });
}
