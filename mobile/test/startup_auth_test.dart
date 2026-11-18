import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/core/constants/app_routes.dart';
import 'package:solidaridad_app/core/widgets/loading_screen.dart';
import 'package:solidaridad_app/core/widgets/splash_screen.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/session_store.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/widgets/session_expiry_redirect.dart';

import 'helpers/mock_http_client.dart';

String _jwt([Map<String, Object?> claims = const {}]) {
  String part(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

const _merchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
);

class _Repository extends AuthRepository {
  _Repository(this.lookup)
    : super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  final MerchantLookup lookup;

  @override
  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return AuthResponse(
      isSuccess: true,
      user: User(name: 'Ana', email: 'ana@comercio.test', token: _jwt()),
      merchant: _merchant,
      message: 'ok',
    );
  }

  @override
  Future<MerchantLookup> fetchCurrentMerchant({required String token}) async {
    return lookup;
  }
}

class _Timer implements Timer {
  _Timer(this.callback);

  final void Function() callback;
  var active = true;

  void fire() {
    if (!active) return;
    active = false;
    callback();
  }

  @override
  void cancel() => active = false;

  @override
  bool get isActive => active;

  @override
  int get tick => active ? 0 : 1;
}

class _Schedule {
  final timers = <_Timer>[];

  Timer call(Duration duration, void Function() callback) {
    final timer = _Timer(callback);
    timers.add(timer);
    return timer;
  }
}

Future<void> _pumpStartup(WidgetTester tester, AuthCubit cubit) async {
  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: cubit,
      child: MaterialApp(
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.loading: (_) => const LoadingScreen(),
          AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
          AppRoutes.saleForm: (_) => const Scaffold(body: Text('VENTA')),
          AppRoutes.changePassword: (_) => const Scaffold(body: Text('CLAVE')),
        },
      ),
    ),
  );

  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sin sesión guardada el arranque termina en login', (
    tester,
  ) async {
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: MemorySessionStore(),
    );

    await _pumpStartup(tester, cubit);

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('VENTA'), findsNothing);
    await cubit.close();
  });

  testWidgets('una sesión vigente abre la venta con el comercio', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await store.save(
      PersistedSession(
        user: User(name: 'Ana', email: 'ana@comercio.test', token: _jwt()),
        mustChangePassword: false,
        merchant: _merchant,
      ),
    );
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
      now: () => DateTime.utc(2030),
    );

    await _pumpStartup(tester, cubit);

    expect(find.text('VENTA'), findsOneWidget);
    expect(cubit.merchant?.name, 'COMERCIO REAL');
    await cubit.close();
  });

  testWidgets('mustChangePassword abre el cambio de contraseña', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await store.save(
      PersistedSession(
        user: User(name: 'Ana', email: 'ana@comercio.test', token: _jwt()),
        mustChangePassword: true,
        merchant: _merchant,
      ),
    );
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
    );

    await _pumpStartup(tester, cubit);

    expect(find.text('CLAVE'), findsOneWidget);
    final arguments = ModalRoute.of(
      tester.element(find.text('CLAVE')),
    )?.settings.arguments;
    expect(arguments, <String, dynamic>{'isFirstLogin': true});
    await cubit.close();
  });

  testWidgets('un token con exp vencido vuelve al login', (tester) async {
    final store = MemorySessionStore();
    final exp = DateTime.utc(2020).millisecondsSinceEpoch ~/ 1000;
    await store.save(
      PersistedSession(
        user: User(
          name: 'Ana',
          email: 'ana@comercio.test',
          token: _jwt({'exp': exp}),
        ),
        mustChangePassword: false,
        merchant: _merchant,
      ),
    );
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.unavailable()),
      sessionStore: store,
    );

    await _pumpStartup(tester, cubit);

    expect(find.text('LOGIN'), findsOneWidget);
    expect(await store.read(), isNull);
    await cubit.close();
  });

  testWidgets('un 401 del refresco vuelve al login', (tester) async {
    final schedule = _Schedule();
    final cubit = AuthCubit(
      authRepository: _Repository(const MerchantLookup.sessionExpired()),
      sessionStore: MemorySessionStore(),
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            return SessionExpiryRedirect(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Scaffold(body: Text('VENTA')),
          routes: {AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN'))},
        ),
      ),
    );

    schedule.timers.single.fire();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('VENTA'), findsNothing);
    await cubit.close();
  });
}
