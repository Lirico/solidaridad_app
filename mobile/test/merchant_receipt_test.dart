import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/data/merchant_store.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';
import 'package:solidaridad_app/features/history/presentation/screens/sale_detail_screen.dart';
import 'package:solidaridad_app/features/sales/data/receipt_printer.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_status_screen.dart';

import 'helpers/mock_http_client.dart';

class MockReceiptPrinter extends Mock implements ReceiptPrinter {}

class ScriptedAuthRepository extends AuthRepository {
  ScriptedAuthRepository(
    this.lookup, {
    Merchant? loginMerchant,
    User? loginUser,
  }) : loginMerchant = loginMerchant ?? _loginMerchant,
       loginUser =
           loginUser ??
           const User(name: 'Ana', email: 'ana@comercio.test', token: 'tok'),
       super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  MerchantLookup lookup;
  Merchant? loginMerchant;
  User loginUser;
  Completer<MerchantLookup>? pendingLookup;
  int fetchCount = 0;

  @override
  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return AuthResponse(
      isSuccess: true,
      user: loginUser,
      merchant: loginMerchant,
      message: 'Inicio de sesión exitoso',
    );
  }

  @override
  Future<MerchantLookup> fetchCurrentMerchant({required String token}) async {
    fetchCount++;
    final pending = pendingLookup;
    if (pending != null) {
      pendingLookup = null;
      return pending.future;
    }
    return lookup;
  }
}

class ManualTimer implements Timer {
  ManualTimer(this.callback);

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

class ManualSchedule {
  final List<Duration> durations = [];
  final List<ManualTimer> timers = [];

  Timer call(Duration duration, void Function() callback) {
    durations.add(duration);
    final timer = ManualTimer(callback);
    timers.add(timer);
    return timer;
  }

  void fireLatest() => timers.last.fire();
}

class SeededAuthCubit extends AuthCubit {
  SeededAuthCubit({required this.repository, Merchant? merchant})
    : super(
        authRepository: repository,
        merchantStore: MerchantStore()..replace(merchant),
      ) {
    emit(
      AuthSuccess(
        user: const User(name: 'Ana', email: 'ana@comercio.test', token: 'tok'),
        merchant: merchant,
      ),
    );
  }

  final ScriptedAuthRepository repository;
}

const Merchant _loginMerchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
);

const Merchant _otherMerchant = Merchant(
  code: '099999',
  name: 'OTRO COMERCIO',
  address: 'San Martín 500',
  city: 'Río Grande',
  taxId: '30-79999999-9',
);

OperationModel _operation() {
  return OperationModel(
    id: 'OP-1',
    productCode: 'GARRAFA_10',
    productLabel: 'Garrafa 10 kg',
    amount: 4,
    cardNumber: '•••• 7403',
    result: PaymentResult.approved,
    date: DateTime(2026, 11, 11, 12),
    couponNumber: '00000042',
    authorizationCode: 'A99881',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(_operation());
    registerFallbackValue(
      ReceiptDefaults.forSale(
        merchantCode: '014114',
        merchantName: 'COMERCIO REAL',
        merchantAddress: 'Alem 100',
        merchantCity: 'Tolhuin',
        merchantTaxId: '30-71234567-8',
        operation: _operation(),
      ),
    );
  });

  test('el login guarda el comercio de la cuenta', () async {
    final client = MockHttpClient();
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'name': 'Ana',
          'email': 'ana@comercio.test',
          'token': 'tok',
          'must_change_password': false,
          'merchant': {
            'code': '014114',
            'name': 'COMERCIO REAL',
            'address': 'Alem 100',
            'city': 'Tolhuin',
            'tax_id': '30-71234567-8',
          },
        }),
        200,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      ),
    );

    final repository = AuthRepository(
      httpClient: client,
      baseUrl: 'http://localhost',
    );
    final response = await repository.login(
      usernameOrEmail: 'ana@comercio.test',
      password: 'secret',
    );

    expect(response.isSuccess, isTrue);
    expect(response.merchant?.code, '014114');
    expect(response.merchant?.name, 'COMERCIO REAL');
    expect(response.merchant?.city, 'Tolhuin');
    expect(response.merchant?.taxId, '30-71234567-8');

    final store = MerchantStore();
    final schedule = ManualSchedule();
    final cubit = AuthCubit(
      authRepository: repository,
      merchantStore: store,
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    final state = cubit.state as AuthSuccess;
    expect(state.merchant?.name, 'COMERCIO REAL');
    expect(store.current?.name, 'COMERCIO REAL');
    expect(cubit.merchant?.name, 'COMERCIO REAL');
    expect(schedule.durations, [const Duration(minutes: 15)]);
    await cubit.close();
  });

  test('a los 15 minutos el refresco exitoso reemplaza el store', () async {
    final repository = ScriptedAuthRepository(
      const MerchantLookup.found(
        Merchant(
          code: '014114',
          name: 'COMERCIO NUEVO',
          address: 'Alem 200',
          city: 'Ushuaia',
          taxId: '30-71234567-8',
        ),
      ),
    );
    final store = MerchantStore();
    final schedule = ManualSchedule();
    final cubit = AuthCubit(
      authRepository: repository,
      merchantStore: store,
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');

    expect(store.current?.name, 'COMERCIO REAL');
    expect(repository.fetchCount, 0);

    schedule.fireLatest();
    await pumpEventQueue();

    expect(repository.fetchCount, 1);
    expect(store.current?.name, 'COMERCIO NUEVO');
    expect((cubit.state as AuthSuccess).merchant?.address, 'Alem 200');
    expect(schedule.durations, const [
      Duration(minutes: 15),
      Duration(minutes: 15),
    ]);
    await cubit.close();
  });

  test(
    'un refresco fallido reintenta, conserva el store y solo escribe un log',
    () async {
      final repository = ScriptedAuthRepository(
        const MerchantLookup.unavailable(),
      );
      final store = MerchantStore();
      final schedule = ManualSchedule();
      final retryDelays = <Duration>[];
      final logs = <String>[];
      final cubit = AuthCubit(
        authRepository: repository,
        merchantStore: store,
        schedule: schedule.call,
        retryWait: (duration) async => retryDelays.add(duration),
        log: logs.add,
      );
      await cubit.login(
        usernameOrEmail: 'ana@comercio.test',
        password: 'secret',
      );

      schedule.fireLatest();
      await pumpEventQueue();

      expect(repository.fetchCount, 3);
      expect(retryDelays, const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(store.current?.name, 'COMERCIO REAL');
      expect(cubit.state, isA<AuthSuccess>());
      expect(logs, hasLength(1));
      expect(logs.single, contains('próxima ventana'));
      expect(schedule.durations.last, const Duration(minutes: 15));
      await cubit.close();
    },
  );

  test('logout limpia el store y cancela el próximo refresco', () async {
    final repository = ScriptedAuthRepository(
      const MerchantLookup.found(_loginMerchant),
    );
    final store = MerchantStore();
    final schedule = ManualSchedule();
    final cubit = AuthCubit(
      authRepository: repository,
      merchantStore: store,
      schedule: schedule.call,
    );
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    final scheduled = schedule.timers.single;

    await cubit.logout();
    scheduled.fire();
    await pumpEventQueue();

    expect(store.current, isNull);
    expect(cubit.merchant, isNull);
    expect(scheduled.isActive, isFalse);
    expect(repository.fetchCount, 0);
    await cubit.close();
  });

  test(
    'una respuesta de refresco posterior al logout no restaura el merchant',
    () async {
      final repository = ScriptedAuthRepository(
        const MerchantLookup.found(_otherMerchant),
      );
      final pending = Completer<MerchantLookup>();
      repository.pendingLookup = pending;
      final store = MerchantStore();
      final schedule = ManualSchedule();
      final cubit = AuthCubit(
        authRepository: repository,
        merchantStore: store,
        schedule: schedule.call,
      );
      await cubit.login(
        usernameOrEmail: 'ana@comercio.test',
        password: 'secret',
      );

      schedule.fireLatest();
      await pumpEventQueue();
      expect(repository.fetchCount, 1);

      await cubit.logout();
      pending.complete(const MerchantLookup.found(_otherMerchant));
      await pumpEventQueue();

      expect(store.current, isNull);
      expect(cubit.state, isA<AuthInitial>());
      expect(schedule.timers, hasLength(1));
      await cubit.close();
    },
  );

  test(
    'una respuesta de la cuenta anterior no pisa el merchant del nuevo login',
    () async {
      final repository = ScriptedAuthRepository(
        const MerchantLookup.found(_loginMerchant),
      );
      final pending = Completer<MerchantLookup>();
      repository.pendingLookup = pending;
      final store = MerchantStore();
      final schedule = ManualSchedule();
      final cubit = AuthCubit(
        authRepository: repository,
        merchantStore: store,
        schedule: schedule.call,
      );
      await cubit.login(
        usernameOrEmail: 'ana@comercio.test',
        password: 'secret',
      );
      schedule.fireLatest();
      await pumpEventQueue();

      repository.loginUser = const User(
        name: 'Beto',
        email: 'beto@comercio.test',
        token: 'tok-2',
      );
      repository.loginMerchant = _otherMerchant;
      await cubit.login(
        usernameOrEmail: 'beto@comercio.test',
        password: 'secret-2',
      );
      pending.complete(const MerchantLookup.found(_loginMerchant));
      await pumpEventQueue();

      expect(store.current?.code, _otherMerchant.code);
      final state = cubit.state as AuthSuccess;
      expect(state.user?.token, 'tok-2');
      expect(state.merchant?.name, _otherMerchant.name);
      expect(schedule.timers, hasLength(2));
      await cubit.close();
    },
  );

  for (final failure in <String, MerchantLookup>{
    '403': const MerchantLookup.missing(),
  }.entries) {
    test(
      'un ${failure.key} del refresco conserva la sesión y solo registra log',
      () async {
        final repository = ScriptedAuthRepository(failure.value);
        final store = MerchantStore();
        final schedule = ManualSchedule();
        final retryDelays = <Duration>[];
        final logs = <String>[];
        final cubit = AuthCubit(
          authRepository: repository,
          merchantStore: store,
          schedule: schedule.call,
          retryWait: (duration) async => retryDelays.add(duration),
          log: logs.add,
        );
        await cubit.login(
          usernameOrEmail: 'ana@comercio.test',
          password: 'secret',
        );

        schedule.fireLatest();
        await pumpEventQueue();

        expect(repository.fetchCount, 1);
        expect(retryDelays, isEmpty);
        expect(store.current?.code, _loginMerchant.code);
        expect(cubit.state, isA<AuthSuccess>());
        expect(logs, hasLength(1));
        expect(schedule.durations, const [
          Duration(minutes: 15),
          Duration(minutes: 15),
        ]);
        await cubit.close();
      },
    );
  }

  testWidgets('sin comercio no se llama a la impresora', (tester) async {
    final printer = MockReceiptPrinter();
    final repository = ScriptedAuthRepository(const MerchantLookup.missing());
    await _openStatus(
      tester,
      cubit: SeededAuthCubit(repository: repository),
      printer: printer,
    );

    expect(
      find.text('La cuenta no tiene un comercio configurado.'),
      findsOneWidget,
    );
    verifyNever(
      () => printer.printTicket(any(), defaults: any(named: 'defaults')),
    );
    expect(repository.fetchCount, 0);
  });

  testWidgets('el resultado imprime desde el store sin pedir el comercio', (
    tester,
  ) async {
    final printer = MockReceiptPrinter();
    when(
      () => printer.printTicket(any(), defaults: any(named: 'defaults')),
    ).thenAnswer((_) async => const PrintResult.success());
    final repository = ScriptedAuthRepository(
      const MerchantLookup.found(_otherMerchant),
    );

    await _openStatus(
      tester,
      cubit: SeededAuthCubit(repository: repository, merchant: _loginMerchant),
      printer: printer,
    );

    final captured = verify(
      () => printer.printTicket(any(), defaults: captureAny(named: 'defaults')),
    ).captured;
    final defaults = captured.single as ReceiptDefaults;
    expect(defaults.establishmentCode, _loginMerchant.code);
    expect(repository.fetchCount, 0);
  });

  testWidgets('el detalle usa el store sin pedir el comercio', (tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final printer = MockReceiptPrinter();
    when(
      () => printer.printTicket(any(), defaults: any(named: 'defaults')),
    ).thenAnswer((_) async => const PrintResult.success());
    final repository = ScriptedAuthRepository(
      const MerchantLookup.found(
        Merchant(
          code: '014114',
          name: 'COMERCIO NUEVO',
          address: 'Alem 200',
          city: 'Ushuaia',
          taxId: '30-70000000-1',
        ),
      ),
    );

    await tester.pumpWidget(
      BlocProvider<AuthCubit>(
        create: (_) =>
            SeededAuthCubit(repository: repository, merchant: _loginMerchant),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder<void>(
                      settings: RouteSettings(arguments: _operation()),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) =>
                          SaleDetailScreen(printer: printer),
                    ),
                  );
                },
                child: const Text('abrir'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump();

    expect(find.text('COMERCIO REAL'), findsOneWidget);
    expect(find.text('Alem 100, Tolhuin'), findsOneWidget);
    expect(find.text('Cupón: 00000042'), findsOneWidget);
    expect(find.text('Autorización: A99881'), findsOneWidget);
    expect(find.textContaining('Lote:'), findsNothing);
    expect(find.text('Gas Austral'), findsNothing);

    await tester.tap(find.text('IMPRIMIR TICKET'));
    await tester.pump();
    await tester.pump();

    final captured = verify(
      () => printer.printTicket(any(), defaults: captureAny(named: 'defaults')),
    ).captured;
    final defaults = captured.single as ReceiptDefaults;
    expect(defaults.establishmentName, 'COMERCIO REAL');
    expect(defaults.couponNumber, '00000042');
    expect(repository.fetchCount, 0);
  });
}

Future<void> _openStatus(
  WidgetTester tester, {
  required AuthCubit cubit,
  required ReceiptPrinter printer,
}) async {
  tester.view.physicalSize = const Size(720, 1440);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: cubit,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder<void>(
                    settings: RouteSettings(arguments: _operation()),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) =>
                        SaleStatusScreen(printer: printer),
                  ),
                );
              },
              child: const Text('abrir'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump();
}
