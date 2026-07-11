import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/sales/data/sales_repository.dart';
import 'features/sales/presentation/cubit/sales_cubit.dart';

// Importaciones de pantallas
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart'; // <-- NUEVO
import 'features/sales/presentation/screens/sale_form_screen.dart';
import 'features/sales/presentation/screens/sale_review_screen.dart';
import 'features/sales/presentation/screens/sale_status_screen.dart';
import 'features/history/presentation/screens/sales_history_screen.dart';
import 'features/history/presentation/screens/sale_detail_screen.dart'; // <-- NUEVO

void main() {
  final salesRepository = SalesRepository();

  runApp(
    BlocProvider<SalesCubit>(
      create: (context) => SalesCubit(salesRepository: salesRepository),
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
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/change_password': (context) =>
            const ChangePasswordScreen(), // <-- NUEVO
        '/sales_form': (context) => const SaleFormScreen(),
        '/sale_review': (context) => const SaleReviewScreen(),
        '/sale_status': (context) => const SaleStatusScreen(),
        '/sales_history': (context) => const SalesHistoryScreen(),
        '/sale_detail': (context) => const SaleDetailScreen(), // <-- NUEVO
      },
    );
  }
}
