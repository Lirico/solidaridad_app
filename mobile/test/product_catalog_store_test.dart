import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/session_store.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';
import 'package:solidaridad_app/features/sales/data/product_catalog_store.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

import 'helpers/mock_http_client.dart';

const _catalogA = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa 10 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
];

const _catalogB = <ProductInfo>[
  ProductInfo(
    code: 'GRANEL',
    label: 'Granel actualizado',
    unit: ProductUnit(singular: 'm3', plural: 'm3'),
  ),
];

class _ProductsRepository extends SalesRepository {
  _ProductsRepository(List<Object> script)
    : _script = List<Object>.from(script),
      super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  final List<Object> _script;
  Completer<List<ProductInfo>>? pending;
  int fetchCount = 0;

  @override
  Future<List<ProductInfo>> fetchProducts({required String token}) async {
    fetchCount++;
    final active = pending;
    if (active != null) {
      pending = null;
      return active.future;
    }
    final next = _script.removeAt(0);
    if (next is Exception) throw next;
    if (next is Completer<List<ProductInfo>>) return next.future;
    return next as List<ProductInfo>;
  }

  void enqueue(Object result) => _script.add(result);
}

class _Timer implements Timer {
  _Timer(this.callback);

  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick = 1;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

class _Schedule {
  final durations = <Duration>[];
  final timers = <_Timer>[];

  Timer call(Duration duration, void Function() callback) {
    durations.add(duration);
    final timer = _Timer(callback);
    timers.add(timer);
    return timer;
  }

  void fireLatest() => timers.last.fire();
}

class _AuthRepository extends AuthRepository {
  _AuthRepository({this.changePasswordPending})
    : super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  final Completer<AuthResponse>? changePasswordPending;

  @override
  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return const AuthResponse(
      isSuccess: true,
      user: User(name: 'Ana', email: 'ana@test.com', token: 'tok'),
      merchant: Merchant(
        code: '014114',
        name: 'COMERCIO',
        address: 'Alem 100',
        city: 'Tolhuin',
        taxId: '30-71234567-8',
      ),
      message: 'OK',
    );
  }

  @override
  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final pending = changePasswordPending;
    if (pending != null) return pending.future;
    return const AuthResponse(
      isSuccess: false,
      message: 'Cambio de contraseña no configurado para el test.',
    );
  }
}

String _unsignedJwt() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(<String, Object?>{})}.sig';
}

void main() {
  test('carga al iniciar y refresca con cadencia de 15 minutos', () async {
    final repository = _ProductsRepository([_catalogA, _catalogB]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    addTearDown(() => store.stop(clear: true));

    await store.start(token: 'tok');

    expect(repository.fetchCount, 1);
    expect(store.current?.single.label, 'Garrafa 10 kg');
    expect(schedule.durations, [const Duration(minutes: 15)]);

    expect(await store.getOrLoad(token: 'tok'), _catalogA);
    expect(schedule.durations, [const Duration(minutes: 15)]);

    schedule.fireLatest();
    await pumpEventQueue();

    expect(repository.fetchCount, 2);
    expect(store.current?.single.label, 'Granel actualizado');
    expect(schedule.durations, const [
      Duration(minutes: 15),
      Duration(minutes: 15),
    ]);
  });

  test('el primer acceso inicializa el store y comparte el request', () async {
    final repository = _ProductsRepository(const []);
    final pending = Completer<List<ProductInfo>>();
    repository.pending = pending;
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    addTearDown(() => store.stop(clear: true));

    final first = store.getOrLoad(token: 'tok');
    final second = store.getOrLoad(token: 'tok');
    expect(repository.fetchCount, 1);

    pending.complete(_catalogA);
    expect(await first, _catalogA);
    expect(await second, _catalogA);
    expect(await store.getOrLoad(token: 'tok'), _catalogA);
    expect(repository.fetchCount, 1);
    expect(store.isInitialized, isTrue);
  });

  test('start y el primer acceso concurrente comparten el request', () async {
    final pending = Completer<List<ProductInfo>>();
    final repository = _ProductsRepository([pending]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    addTearDown(() => store.stop(clear: true));

    final start = store.start(token: 'tok');
    final access = store.getOrLoad(token: 'tok');
    expect(repository.fetchCount, 1);

    pending.complete(_catalogA);
    await start;
    expect(await access, _catalogA);
    expect(schedule.durations, [const Duration(minutes: 15)]);
  });

  test('un fallo post-login se recupera en el siguiente acceso', () async {
    final repository = _ProductsRepository([
      const DataLoadException('sin red'),
      const DataLoadException('sin red'),
      const DataLoadException('sin red'),
      _catalogB,
    ]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
      retryWait: (_) async {},
      log: (_) {},
    );
    final cubit = AuthCubit(
      authRepository: _AuthRepository(),
      productCatalogStore: store,
      sessionStore: MemorySessionStore(),
      schedule: _Schedule().call,
    );

    await cubit.login(usernameOrEmail: 'ana@test.com', password: 'secret');
    await pumpEventQueue();
    expect(store.current, isNull);
    expect(repository.fetchCount, 3);

    expect(await store.getOrLoad(token: 'tok'), _catalogB);
    expect(repository.fetchCount, 4);
    expect(schedule.durations, [const Duration(minutes: 15)]);
    await cubit.close();
  });

  test(
    'una respuesta de la sesión anterior no pisa el catálogo nuevo',
    () async {
      final oldResponse = Completer<List<ProductInfo>>();
      final repository = _ProductsRepository([oldResponse, _catalogB]);
      final store = ProductCatalogStore(
        repository: repository,
        schedule: _Schedule().call,
        retryWait: (_) async {},
      );
      addTearDown(() => store.stop(clear: true));

      final oldLoad = store.getOrLoad(token: 'old-token');
      expect(repository.fetchCount, 1);
      expect(await store.getOrLoad(token: 'new-token'), _catalogB);

      oldResponse.complete(_catalogA);
      await expectLater(oldLoad, throwsA(isA<DataLoadException>()));

      expect(store.current, _catalogB);
      expect(repository.fetchCount, 2);
    },
  );

  test('un fallo periódico conserva el catálogo y reintenta 1s/2s', () async {
    final repository = _ProductsRepository([_catalogA]);
    final schedule = _Schedule();
    final waits = <Duration>[];
    final logs = <String>[];
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
      retryWait: (duration) async => waits.add(duration),
      log: logs.add,
    );
    addTearDown(() => store.stop(clear: true));
    await store.start(token: 'tok');
    repository
      ..enqueue(const DataLoadException('sin red'))
      ..enqueue(const DataLoadException('sin red'))
      ..enqueue(const DataLoadException('sin red'));

    schedule.fireLatest();
    await pumpEventQueue();

    expect(repository.fetchCount, 4);
    expect(waits, const [Duration(seconds: 1), Duration(seconds: 2)]);
    expect(store.current, _catalogA);
    expect(logs.single, contains('próxima ventana'));
    expect(schedule.durations.last, const Duration(minutes: 15));
  });

  test('un catálogo vacío durante el refresh conserva el anterior', () async {
    final repository = _ProductsRepository([
      _catalogA,
      const <ProductInfo>[],
      const <ProductInfo>[],
      const <ProductInfo>[],
    ]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
      retryWait: (_) async {},
      log: (_) {},
    );
    addTearDown(() => store.stop(clear: true));
    await store.start(token: 'tok');

    schedule.fireLatest();
    await pumpEventQueue();

    expect(repository.fetchCount, 4);
    expect(store.current, _catalogA);
    expect(schedule.durations.last, const Duration(minutes: 15));
  });

  test('un acceso durante el refresh no crea timers duplicados', () async {
    final repository = _ProductsRepository([_catalogA]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    addTearDown(() => store.stop(clear: true));
    await store.start(token: 'tok');

    final refreshed = Completer<List<ProductInfo>>();
    repository.pending = refreshed;
    schedule.fireLatest();
    expect(await store.getOrLoad(token: 'tok'), _catalogA);
    expect(schedule.durations.length, 2);

    refreshed.complete(_catalogB);
    await pumpEventQueue();

    expect(store.current, _catalogB);
    expect(schedule.durations.length, 2);
    expect(schedule.timers.where((timer) => timer.isActive).length, 1);
  });

  test('un 401 limpia el catálogo y notifica la sesión expirada', () async {
    final repository = _ProductsRepository([_catalogA]);
    final schedule = _Schedule();
    var expired = 0;
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    addTearDown(() => store.stop(clear: true));
    await store.start(token: 'tok', onSessionExpired: () async => expired++);
    repository.enqueue(const SessionExpiredException());

    schedule.fireLatest();
    await pumpEventQueue();

    expect(expired, 1);
    expect(store.current, isNull);
    expect(schedule.timers.last.isActive, isFalse);
  });

  test(
    'un 401 durante cambio de contraseña expira la sesión sin resucitarla',
    () async {
      final repository = _ProductsRepository([_catalogA]);
      final productSchedule = _Schedule();
      final store = ProductCatalogStore(
        repository: repository,
        schedule: productSchedule.call,
      );
      final passwordResponse = Completer<AuthResponse>();
      final sessions = MemorySessionStore();
      final cubit = AuthCubit(
        authRepository: _AuthRepository(
          changePasswordPending: passwordResponse,
        ),
        productCatalogStore: store,
        sessionStore: sessions,
        schedule: _Schedule().call,
      );

      await cubit.login(usernameOrEmail: 'ana@test.com', password: 'secret');
      await pumpEventQueue();
      repository.enqueue(const SessionExpiredException());

      final passwordChange = cubit.changePassword(
        currentPassword: 'secret',
        newPassword: 'new-secret',
      );
      expect(cubit.state, isA<AuthLoading>());

      productSchedule.fireLatest();
      await pumpEventQueue();

      expect(cubit.state, isA<AuthSessionExpired>());
      expect(store.current, isNull);
      expect(await sessions.read(), isNull);

      passwordResponse.complete(
        const AuthResponse(isSuccess: true, message: 'Contraseña actualizada.'),
      );
      await passwordChange;

      expect(cubit.state, isA<AuthSessionExpired>());
      expect(await sessions.read(), isNull);
      await cubit.close();
    },
  );

  test('login y restore disparan la primera carga del catálogo', () async {
    final repository = _ProductsRepository([_catalogA, _catalogB]);
    final productSchedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: productSchedule.call,
    );
    final sessions = MemorySessionStore();
    final merchantSchedule = _Schedule();
    final first = AuthCubit(
      authRepository: _AuthRepository(),
      productCatalogStore: store,
      sessionStore: sessions,
      schedule: merchantSchedule.call,
    );

    await first.login(usernameOrEmail: 'ana@test.com', password: 'secret');
    await pumpEventQueue();

    expect(first.state, isA<AuthSuccess>());
    expect(repository.fetchCount, 1);
    expect(store.current, _catalogA);
    await first.close();

    await sessions.save(
      PersistedSession(
        user: User(name: 'Ana', email: 'ana@test.com', token: _unsignedJwt()),
        mustChangePassword: false,
        merchant: const Merchant(
          code: '014114',
          name: 'COMERCIO',
          address: 'Alem 100',
          city: 'Tolhuin',
          taxId: '30-71234567-8',
        ),
      ),
    );
    final restoredStore = ProductCatalogStore(
      repository: repository,
      schedule: _Schedule().call,
    );
    final second = AuthCubit(
      authRepository: _AuthRepository(),
      productCatalogStore: restoredStore,
      sessionStore: sessions,
      schedule: _Schedule().call,
    );

    await second.restore();
    await pumpEventQueue();

    expect(second.state, isA<AuthSuccess>());
    expect(repository.fetchCount, 2);
    expect(restoredStore.current, _catalogB);
    await second.close();
  });

  test('logout limpia el catálogo y cancela el refresco', () async {
    final repository = _ProductsRepository([_catalogA]);
    final productSchedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: productSchedule.call,
    );
    final cubit = AuthCubit(
      authRepository: _AuthRepository(),
      productCatalogStore: store,
      sessionStore: MemorySessionStore(),
      schedule: _Schedule().call,
    );

    await cubit.login(usernameOrEmail: 'ana@test.com', password: 'secret');
    await pumpEventQueue();
    final refreshTimer = productSchedule.timers.single;

    await cubit.logout();

    expect(store.current, isNull);
    expect(store.isInitialized, isFalse);
    expect(refreshTimer.isActive, isFalse);
    await cubit.close();
  });

  test('restore sin sesión limpia un catálogo previamente cargado', () async {
    final store = ProductCatalogStore(
      repository: _ProductsRepository([_catalogA]),
      schedule: _Schedule().call,
    );
    await store.start(token: 'tok');
    expect(store.current, _catalogA);
    final cubit = AuthCubit(
      authRepository: _AuthRepository(),
      productCatalogStore: store,
      sessionStore: MemorySessionStore(),
      schedule: _Schedule().call,
    );

    await cubit.restore();

    expect(cubit.state, isA<AuthInitial>());
    expect(store.current, isNull);
    expect(store.isInitialized, isFalse);
    await cubit.close();
  });
}
