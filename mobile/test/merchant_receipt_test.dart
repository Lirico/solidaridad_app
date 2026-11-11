import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
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
  ScriptedAuthRepository(this.lookup)
    : super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  MerchantLookup lookup;

  @override
  Future<MerchantLookup> fetchCurrentMerchant({required String token}) async {
    return lookup;
  }
}

class SeededAuthCubit extends AuthCubit {
  SeededAuthCubit({required this.repository, this.merchant})
    : super(authRepository: repository) {
    emit(
      AuthSuccess(
        user: const User(name: 'Ana', email: 'ana@comercio.test', token: 'tok'),
        merchant: merchant,
      ),
    );
  }

  final ScriptedAuthRepository repository;
  final Merchant? merchant;
}

const Merchant _loginMerchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
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

    final cubit = AuthCubit(authRepository: repository);
    await cubit.login(usernameOrEmail: 'ana@comercio.test', password: 'secret');
    final state = cubit.state as AuthSuccess;
    expect(state.merchant?.name, 'COMERCIO REAL');
    await cubit.close();
  });

  test(
    'el refresco actualiza el comercio y un corte de red conserva el login',
    () async {
      final repository = ScriptedAuthRepository(
        const MerchantLookup.unavailable(),
      );
      final cubit = SeededAuthCubit(
        repository: repository,
        merchant: _loginMerchant,
      );

      expect((await cubit.refreshMerchant())?.name, 'COMERCIO REAL');

      repository.lookup = const MerchantLookup.found(
        Merchant(
          code: '014114',
          name: 'COMERCIO NUEVO',
          address: 'Alem 200',
          city: 'Ushuaia',
          taxId: '30-71234567-8',
        ),
      );
      expect((await cubit.refreshMerchant())?.name, 'COMERCIO NUEVO');
      expect((cubit.state as AuthSuccess).merchant?.address, 'Alem 200');

      repository.lookup = const MerchantLookup.missing();
      expect(await cubit.refreshMerchant(), isNull);
      expect((cubit.state as AuthSuccess).merchant, isNull);
      await cubit.close();
    },
  );

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
  });

  testWidgets('el detalle muestra el comercio refrescado', (tester) async {
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

    expect(find.text('COMERCIO NUEVO'), findsOneWidget);
    expect(find.text('Alem 200, Ushuaia'), findsOneWidget);
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
    expect(defaults.establishmentName, 'COMERCIO NUEVO');
    expect(defaults.couponNumber, '00000042');
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
