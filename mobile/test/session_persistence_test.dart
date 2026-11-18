import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/merchant_store.dart';
import 'package:solidaridad_app/features/auth/data/secure_session_store.dart';
import 'package:solidaridad_app/features/auth/data/session_store.dart';
import 'package:solidaridad_app/features/auth/domain/access_token.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';

import 'helpers/mock_http_client.dart';

const _merchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
);

const _refreshed = Merchant(
  code: '014114',
  name: 'COMERCIO NUEVO',
  address: 'Alem 200',
  city: 'Ushuaia',
  taxId: '30-71234567-8',
);

String unsignedJwt([Map<String, Object?> claims = const {}]) {
  String part(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

class _Repository extends AuthRepository {
  _Repository(this.lookup)
    : super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  MerchantLookup lookup;
  bool mustChangePassword = false;
  bool passwordChanged = false;
  int fetchCount = 0;

  @override
  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return AuthResponse(
      isSuccess: true,
      user: User(name: 'Ana', email: 'ana@comercio.test', token: unsignedJwt()),
      merchant: _merchant,
      message: 'Inicio de sesión exitoso',
      mustChangePassword: mustChangePassword,
    );
  }

  @override
  Future<MerchantLookup> fetchCurrentMerchant({required String token}) async {
    fetchCount++;
    return lookup;
  }

  @override
  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    passwordChanged = true;
    return const AuthResponse(
      isSuccess: true,
      message: 'Contraseña actualizada correctamente',
    );
  }
}

class _Timer implements Timer {
  _Timer(this.callback);

  final void Function() callback;
  var _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

class _Schedule {
  final timers = <_Timer>[];

  Timer call(Duration duration, void Function() callback) {
    final timer = _Timer(callback);
    timers.add(timer);
    return timer;
  }

  void fireLatest() => timers.last.fire();
}

void main() {
  test('un token sin exp sigue vigente después de 24 horas', () {
    final later = DateTime.utc(2030);
    expect(
      accessTokenStatus(unsignedJwt(), now: later),
      AccessTokenStatus.valid,
    );
  });

  test('un token con exp futuro es vigente y uno vencido no', () {
    final now = DateTime.utc(2026, 11, 12, 18);
    final future =
        now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final past =
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

    expect(
      accessTokenStatus(unsignedJwt({'exp': future}), now: now),
      AccessTokenStatus.valid,
    );
    expect(
      accessTokenStatus(unsignedJwt({'exp': past}), now: now),
      AccessTokenStatus.expired,
    );
    expect(
      accessTokenStatus('no-es-jwt', now: now),
      AccessTokenStatus.unreadable,
    );
  });

  test('un json ilegible no es una sesión', () {
    expect(PersistedSession.tryDecode('{'), isNull);
    expect(PersistedSession.tryDecode('{"token":""}'), isNull);
  });

  test('el almacenamiento seguro borra un registro ilegible', () async {
    final data = <String, String>{'auth_session': '{'};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      data,
    );

    final session = await SecureSessionStore().read();

    expect(session, isNull);
    expect(data.containsKey('auth_session'), isFalse);
  });

  test(
    'el login se restaura con el comercio después de cerrar el cubit',
    () async {
      final store = MemorySessionStore();
      final firstSchedule = _Schedule();
      final first = AuthCubit(
        authRepository: _Repository(const MerchantLookup.unavailable()),
        sessionStore: store,
        schedule: firstSchedule.call,
      );
      await first.login(
        usernameOrEmail: 'ana@comercio.test',
        password: 'secret',
      );
      await first.close();

      final secondSchedule = _Schedule();
      final second = AuthCubit(
        authRepository: _Repository(const MerchantLookup.unavailable()),
        sessionStore: store,
        schedule: secondSchedule.call,
        now: () => DateTime.utc(2030),
      );
      await second.restore();

      final state = second.state as AuthSuccess;
      expect(state.user?.email, 'ana@comercio.test');
      expect(state.merchant?.name, 'COMERCIO REAL');
      expect(second.merchant?.city, 'Tolhuin');
      expect(secondSchedule.timers, hasLength(1));
      await second.close();
    },
  );

  test('mustChangePassword se conserva hasta un cambio exitoso', () async {
    final store = MemorySessionStore();
    final repository = _Repository(const MerchantLookup.unavailable())
      ..mustChangePassword = true;
    final cubit = AuthCubit(
      authRepository: repository,
      sessionStore: store,
      schedule: _Schedule().call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    expect((cubit.state as AuthSuccess).mustChangePassword, isTrue);

    await cubit.changePassword(currentPassword: 'secret', newPassword: 'nueva');

    expect((cubit.state as AuthSuccess).mustChangePassword, isFalse);
    final saved = await store.read();
    expect(saved?.mustChangePassword, isFalse);
    expect(saved?.merchant?.name, 'COMERCIO REAL');
    await cubit.close();
  });

  test('logout borra la sesión y el restore queda en el login', () async {
    final store = MemorySessionStore();
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
      schedule: _Schedule().call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    await cubit.logout();

    final restarted = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
      schedule: _Schedule().call,
    );
    await restarted.restore();

    expect(restarted.state, isA<AuthInitial>());
    expect(restarted.merchant, isNull);
    expect(await store.read(), isNull);
    await restarted.close();
  });

  test('un token con exp vencido no se restaura', () async {
    final store = MemorySessionStore();
    final expiredAt = DateTime.utc(2026, 11, 12).millisecondsSinceEpoch ~/ 1000;
    await store.save(
      PersistedSession(
        user: User(
          name: 'Ana',
          email: 'ana@comercio.test',
          token: unsignedJwt({'exp': expiredAt}),
        ),
        mustChangePassword: false,
        merchant: _merchant,
      ),
    );
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
      now: () => DateTime.utc(2026, 11, 12, 1),
    );
    await cubit.restore();

    expect(cubit.state, isA<AuthInitial>());
    expect(await store.read(), isNull);
    await cubit.close();
  });

  test('un token con exp vigente se restaura', () async {
    final store = MemorySessionStore();
    final now = DateTime.utc(2026, 11, 12, 18);
    final exp =
        now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    await store.save(
      PersistedSession(
        user: User(
          name: 'Ana',
          email: 'ana@comercio.test',
          token: unsignedJwt({'exp': exp}),
        ),
        mustChangePassword: false,
        merchant: _merchant,
      ),
    );
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      merchantStore: MerchantStore(),
      sessionStore: store,
      now: () => now,
    );
    await cubit.restore();

    expect((cubit.state as AuthSuccess).user?.name, 'Ana');
    expect(cubit.merchant?.taxId, _merchant.taxId);
    await cubit.close();
  });

  test('el refresco exitoso actualiza el comercio guardado', () async {
    final store = MemorySessionStore();
    final schedule = _Schedule();
    final repository = _Repository(const MerchantLookup.found(_refreshed));
    final cubit = AuthCubit(
      authRepository: repository,
      sessionStore: store,
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');

    schedule.fireLatest();
    await pumpEventQueue();

    expect((await store.read())?.merchant?.name, 'COMERCIO NUEVO');
    expect(cubit.merchant?.address, 'Alem 200');
    await cubit.close();
  });

  test('un refresco con fallo de red conserva el comercio guardado', () async {
    final store = MemorySessionStore();
    final schedule = _Schedule();
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
      schedule: schedule.call,
      retryWait: (_) async {},
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');

    schedule.fireLatest();
    await pumpEventQueue();

    expect((await store.read())?.merchant?.name, 'COMERCIO REAL');
    expect(cubit.state, isA<AuthSuccess>());
    await cubit.close();
  });

  test('un 401 del refresco borra la sesión', () async {
    final store = MemorySessionStore();
    final schedule = _Schedule();
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.sessionExpired()),
      sessionStore: store,
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    expect(schedule.timers, hasLength(1));

    schedule.fireLatest();
    await pumpEventQueue();

    expect(cubit.state, isA<AuthSessionExpired>());
    expect(cubit.merchant, isNull);
    expect(await store.read(), isNull);
    expect(schedule.timers, hasLength(1));
    await cubit.close();
  });
}
