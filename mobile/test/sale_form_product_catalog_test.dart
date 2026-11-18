import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solidaridad_app/core/constants/app_routes.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/domain/auth_model.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_state.dart';
import 'package:solidaridad_app/features/sales/data/product_catalog_store.dart';
import 'package:solidaridad_app/features/sales/data/sales_repository.dart';
import 'package:solidaridad_app/features/sales/domain/sale_model.dart';
import 'package:solidaridad_app/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:solidaridad_app/features/sales/presentation/screens/sale_form_screen.dart';

import 'helpers/mock_http_client.dart';

const _catalogA = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa original',
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

const _catalogARenamed = <ProductInfo>[
  ProductInfo(
    code: 'GARRAFA_10',
    label: 'Garrafa renombrada',
    unit: ProductUnit(singular: 'unidad', plural: 'unidades'),
  ),
];

class _ProductsRepository extends SalesRepository {
  _ProductsRepository(List<List<ProductInfo>> responses)
    : _responses = List<List<ProductInfo>>.from(responses),
      super(httpClient: MockHttpClient(), baseUrl: 'http://localhost');

  final List<List<ProductInfo>> _responses;
  int fetchCount = 0;

  void enqueue(List<ProductInfo> products) => _responses.add(products);

  @override
  Future<List<ProductInfo>> fetchProducts({required String token}) async {
    fetchCount++;
    return _responses.removeAt(0);
  }
}

class _Timer implements Timer {
  _Timer(this.callback);

  final void Function() callback;
  bool _active = true;

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

class _SeededAuthCubit extends AuthCubit {
  _SeededAuthCubit()
    : super(
        authRepository: AuthRepository(
          httpClient: MockHttpClient(),
          baseUrl: 'http://localhost',
        ),
      ) {
    emit(
      const AuthSuccess(
        user: User(name: 'Ana', email: 'ana@test.com', token: 'tok'),
      ),
    );
  }
}

Future<void> _pumpSaleForm(
  WidgetTester tester, {
  required ProductCatalogStore store,
  required SalesCubit salesCubit,
  required AuthCubit authCubit,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ProductCatalogStore>.value(
      value: store,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<SalesCubit>.value(value: salesCubit),
        ],
        child: MaterialApp(
          home: const SaleFormScreen(),
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
            AppRoutes.saleForm: (_) => const SaleFormScreen(),
            AppRoutes.saleSelectNewOperation: (_) =>
                const Scaffold(body: Text('SIGUIENTE PANTALLA')),
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('el formulario inicializa el catálogo desde el store', (
    tester,
  ) async {
    final repository = _ProductsRepository([_catalogA]);
    final store = ProductCatalogStore(
      repository: repository,
      schedule: _Schedule().call,
    );
    final salesCubit = SalesCubit(
      salesRepository: SalesRepository(
        httpClient: MockHttpClient(),
        baseUrl: 'http://localhost',
      ),
    );
    final authCubit = _SeededAuthCubit();

    await _pumpSaleForm(
      tester,
      store: store,
      salesCubit: salesCubit,
      authCubit: authCubit,
    );

    expect(repository.fetchCount, 1);
    expect(find.text('Garrafa original'), findsWidgets);
    expect(find.text('Cantidad (unidades)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.stop(clear: true);
    await salesCubit.close();
    await authCubit.close();
  });

  testWidgets('un refresh actualiza un formulario que permanece abierto', (
    tester,
  ) async {
    final repository = _ProductsRepository([_catalogA]);
    final schedule = _Schedule();
    final store = ProductCatalogStore(
      repository: repository,
      schedule: schedule.call,
    );
    final salesCubit = SalesCubit(
      salesRepository: SalesRepository(
        httpClient: MockHttpClient(),
        baseUrl: 'http://localhost',
      ),
    );
    final authCubit = _SeededAuthCubit();
    await _pumpSaleForm(
      tester,
      store: store,
      salesCubit: salesCubit,
      authCubit: authCubit,
    );
    expect(find.text('Garrafa original'), findsWidgets);

    repository.enqueue(_catalogARenamed);
    schedule.fireLatest();
    await tester.pump();
    await tester.pump();

    expect(repository.fetchCount, 2);
    expect(find.text('Garrafa original'), findsNothing);
    expect(find.text('Garrafa renombrada'), findsWidgets);
    expect(find.text('Cantidad (unidades)'), findsOneWidget);

    repository.enqueue(_catalogB);
    schedule.fireLatest();
    await tester.pump();
    await tester.pump();

    expect(repository.fetchCount, 3);
    expect(find.text('Garrafa renombrada'), findsNothing);
    expect(find.text('Granel actualizado'), findsWidgets);
    expect(find.text('Cantidad (m3)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.stop(clear: true);
    await salesCubit.close();
    await authCubit.close();
  });
}
