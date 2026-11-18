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
import 'package:solidaridad_app/features/balance/data/balance_repository.dart';
import 'package:solidaridad_app/features/balance/domain/balance_model.dart';
import 'package:solidaridad_app/features/balance/presentation/cubit/balance_cubit.dart';
import 'package:solidaridad_app/features/balance/presentation/cubit/balance_state.dart';
import 'package:solidaridad_app/features/balance/presentation/screens/balance_status_screen.dart';
import 'package:solidaridad_app/features/sales/data/product_catalog_store.dart';
import 'package:solidaridad_app/features/sales/data/receipt_printer.dart';
import 'package:solidaridad_app/features/sales/domain/receipt_defaults.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';

class _Client extends Fake implements http.Client {}

class _ReceiptPrinter extends Mock implements ReceiptPrinter {}

class _ProductCatalogStore extends Mock implements ProductCatalogStore {}

const Merchant _merchant = Merchant(
  code: '014114',
  name: 'COMERCIO REAL',
  address: 'Alem 100',
  city: 'Tolhuin',
  taxId: '30-71234567-8',
);

const List<ProductInfo> _products = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa 10 kg',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
];

ReceiptDefaults _fallbackDefaults() => ReceiptDefaults.forMerchant(
  merchantCode: '000000',
  merchantName: 'Fallback',
  merchantAddress: '',
  merchantCity: '',
  merchantTaxId: '',
);

class _SeededBalanceCubit extends BalanceCubit {
  _SeededBalanceCubit(BalanceState state)
    : super(repository: BalanceRepository(httpClient: _Client())) {
    emit(state);
  }
}

class _SeededAuthCubit extends AuthCubit {
  _SeededAuthCubit({Merchant? merchant})
    : super(
        authRepository: AuthRepository(),
        merchantStore: MerchantStore()..replace(merchant),
      ) {
    emit(
      AuthSuccess(
        user: const User(name: 'Ana', email: 'ana@test.com', token: 'tok'),
        merchant: merchant,
      ),
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2000));
    registerFallbackValue(_fallbackDefaults());
    registerFallbackValue(<ProductQuantity>[]);
  });

  testWidgets('una consulta aprobada imprime el ticket una sola vez', (
    tester,
  ) async {
    final printer = _ReceiptPrinter();
    final productCatalogStore = _ProductCatalogStore();
    when(
      () => productCatalogStore.getOrLoad(token: 'tok'),
    ).thenAnswer((_) async => _products);
    when(
      () => printer.printBalanceTicket(
        date: any(named: 'date'),
        defaults: any(named: 'defaults'),
        cardNumber: any(named: 'cardNumber'),
        expirationDate: any(named: 'expirationDate'),
        balances: any(named: 'balances'),
      ),
    ).thenAnswer((_) async => const PrintResult.success());
    final cubit = _SeededBalanceCubit(
      const BalanceCompleted(
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        result: BalanceResult(
          status: BalanceStatus.approved,
          balances: [
            BalanceItem(
              product: 'GARRAFA_10',
              label: 'Garrafa 10 kg',
              availableBalance: 10.1,
            ),
          ],
          message: 'Consulta de saldo exitosa',
        ),
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => _SeededAuthCubit(merchant: _merchant),
          ),
          BlocProvider<BalanceCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: BalanceStatusScreen(
            printer: printer,
            productCatalogStore: productCatalogStore,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Saldo disponible'), findsOneWidget);
    expect(find.text('10.10 unidades'), findsOneWidget);
    expect(find.text('Ticket impreso'), findsOneWidget);
    final call = verify(
      () => printer.printBalanceTicket(
        date: any(named: 'date'),
        defaults: captureAny(named: 'defaults'),
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        balances: captureAny(named: 'balances'),
      ),
    );
    call.called(1);
    final defaults = call.captured[0] as ReceiptDefaults;
    expect(defaults.establishmentCode, _merchant.code);
    expect(defaults.establishmentName, _merchant.name);
    expect(defaults.establishmentAddress, 'Alem 100, Tolhuin');
    expect(defaults.establishmentCuit, _merchant.taxId);
    expect(defaults.batchNumber, 'ACTUAL');
    final balances = call.captured[1] as List<ProductQuantity>;
    expect(balances.single.product.label, 'Garrafa 10 kg');
    expect(balances.single.quantity, closeTo(10.1, 0.001));
    expect(balances.single.unitLabel, 'unidades');
    verify(() => productCatalogStore.getOrLoad(token: 'tok')).called(1);
  });

  testWidgets('una consulta rechazada no imprime', (tester) async {
    final printer = _ReceiptPrinter();
    final productCatalogStore = _ProductCatalogStore();
    final cubit = _SeededBalanceCubit(
      const BalanceCompleted(
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        result: BalanceResult(
          status: BalanceStatus.declined,
          balances: [],
          message: 'Tarjeta inexistente',
        ),
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => _SeededAuthCubit(merchant: _merchant),
          ),
          BlocProvider<BalanceCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: BalanceStatusScreen(
            printer: printer,
            productCatalogStore: productCatalogStore,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Consulta Rechazada'), findsOneWidget);
    verifyNever(
      () => printer.printBalanceTicket(
        date: any(named: 'date'),
        defaults: any(named: 'defaults'),
        cardNumber: any(named: 'cardNumber'),
        expirationDate: any(named: 'expirationDate'),
        balances: any(named: 'balances'),
      ),
    );
    verifyNever(
      () => productCatalogStore.getOrLoad(token: any(named: 'token')),
    );
  });

  testWidgets('sin comercio muestra error y no imprime', (tester) async {
    final printer = _ReceiptPrinter();
    final productCatalogStore = _ProductCatalogStore();
    when(
      () => productCatalogStore.getOrLoad(token: 'tok'),
    ).thenAnswer((_) async => _products);
    final cubit = _SeededBalanceCubit(
      const BalanceCompleted(
        cardNumber: '6063007014007403',
        expirationDate: '2808',
        result: BalanceResult(
          status: BalanceStatus.approved,
          balances: [],
          message: 'Consulta de saldo exitosa',
        ),
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(create: (_) => _SeededAuthCubit()),
          BlocProvider<BalanceCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: BalanceStatusScreen(
            printer: printer,
            productCatalogStore: productCatalogStore,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('La cuenta no tiene un comercio configurado.'),
      findsOneWidget,
    );
    expect(find.text('REIMPRIMIR'), findsOneWidget);
    verifyNever(
      () => printer.printBalanceTicket(
        date: any(named: 'date'),
        defaults: any(named: 'defaults'),
        cardNumber: any(named: 'cardNumber'),
        expirationDate: any(named: 'expirationDate'),
        balances: any(named: 'balances'),
      ),
    );
    verify(() => productCatalogStore.getOrLoad(token: 'tok')).called(1);
  });
}
