import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Estilos globales
import 'core/theme/app_theme.dart';

// Registro de la lógica de Ventas
import 'features/sales/presentation/cubit/sales_cubit.dart';

// Pantallas de ambas características
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/sales/presentation/screens/sale_form_screen.dart';
import 'features/sales/presentation/screens/sale_review_screen.dart';
import 'features/sales/presentation/screens/sale_status_screen.dart';
import 'features/sales/presentation/screens/sales_history_screen.dart';

void main() {
  runApp(
    // Dejamos el Cubit de ventas arriba en el árbol para que esté disponible
    BlocProvider<SalesCubit>(
      create: (context) => SalesCubit(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAS Terminal',
      debugShowCheckedModeBanner: false,
      theme: appTheme,

      // 1. Definimos que el punto de entrada oficial es el Login
      initialRoute: '/login',

      // 2. El mapa de rutas que vincula las pantallas del MVP
      routes: {
        '/login': (context) => const LoginScreen(),
        '/sales_form': (context) => const SaleFormScreen(),
        '/sale_review': (context) => const SaleReviewScreen(),
        '/sale_status': (context) => const SaleStatusScreen(),
        '/sales_history': (context) => const SalesHistoryScreen(),
      },
    );
  }
}
