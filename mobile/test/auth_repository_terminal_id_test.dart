import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/core/terminal/terminal_id_store.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';

import 'helpers/mock_http_client.dart';

void main() {
  late MockHttpClient client;
  late MemoryTerminalIdStore store;
  late AuthRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    client = MockHttpClient();
    store = MemoryTerminalIdStore();
    repository = AuthRepository(
      httpClient: client,
      baseUrl: 'http://localhost/v1',
      terminalIdStore: store,
    );
  });

  void stubOk({int statusCode = 200}) {
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => jsonMapResponse({
        'name': 'Ada',
        'email': 'a@b.c',
        'token': 'token',
        'must_change_password': false,
      }, statusCode: statusCode),
    );
  }

  String capturedInstallationId() {
    final body =
        verify(
              () => client.post(
                any(),
                headers: any(named: 'headers'),
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as String;
    return (jsonDecode(body) as Map<String, dynamic>)['installation_id']
        as String;
  }

  test('el login no llama al backend si no hay terminal guardada', () async {
    final response = await repository.login(
      usernameOrEmail: 'a@b.c',
      password: 'secret',
    );

    expect(response.isSuccess, isFalse);
    expect(response.message, AuthRepository.missingTerminalMessage);
    verifyNever(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    );
  });

  test('el login envía el código guardado en el equipo', () async {
    await store.save('05000002');
    stubOk();

    final response = await repository.login(
      usernameOrEmail: 'a@b.c',
      password: 'secret',
    );

    expect(response.isSuccess, isTrue);
    expect(capturedInstallationId(), '05000002');
  });

  test('el registro no llama al backend si no hay terminal guardada', () async {
    final response = await repository.register(
      name: 'Ada',
      email: 'a@b.c',
      password: 'secret',
    );

    expect(response.isSuccess, isFalse);
    expect(response.message, AuthRepository.missingTerminalMessage);
    verifyNever(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    );
  });

  test('el registro envía el código guardado en el equipo', () async {
    await store.save('  05000003  ');
    stubOk(statusCode: 201);

    final response = await repository.register(
      name: 'Ada',
      email: 'a@b.c',
      password: 'secret',
    );

    expect(response.isSuccess, isTrue);
    expect(capturedInstallationId(), '05000003');
  });
}
