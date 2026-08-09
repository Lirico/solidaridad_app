import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'features/sales/data/sales_repository.dart';
import 'features/sales/presentation/cubit/sales_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/sales/presentation/screens/sale_form_screen.dart';
import 'features/sales/presentation/screens/sale_processing_screen.dart';
import 'features/sales/presentation/screens/sale_review_screen.dart';
import 'features/sales/presentation/screens/sale_status_screen.dart';
import 'features/sales/presentation/screens/sale_select_new_operation_screen.dart';
import 'features/sales/presentation/screens/sale_manual_card_screen.dart';
import 'features/sales/presentation/screens/sale_waiting_for_card_screen.dart';
import 'features/history/presentation/screens/sales_history_screen.dart';
import 'features/history/presentation/screens/sale_detail_screen.dart';
import 'features/history/presentation/screens/void_card_screen.dart';
import 'features/history/presentation/screens/void_result_screen.dart';
import 'core/widgets/loading_screen.dart';
import 'core/widgets/splash_screen.dart';

void main() {
  final salesRepository = SalesRepository();
  final authRepository = AuthRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<SalesCubit>(
          create: (context) => SalesCubit(salesRepository: salesRepository),
        ),
        BlocProvider<AuthCubit>(
          create: (context) => AuthCubit(authRepository: authRepository),
        ),
      ],
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
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
        AppRoutes.saleForm: (context) => const SaleFormScreen(),
        AppRoutes.saleReview: (context) => const SaleReviewScreen(),
        AppRoutes.saleProcessing: (context) => const SaleProcessingScreen(),
        AppRoutes.saleStatus: (context) => const SaleStatusScreen(),
        AppRoutes.saleSelectNewOperation: (context) =>
            const SelectNewOperationScreen(),
        AppRoutes.saleManualCard: (context) => const SaleManualCardScreen(),
        AppRoutes.saleWaitingForCard: (context) => const WaitingForCardScreen(),
        AppRoutes.salesHistory: (context) => const SalesHistoryScreen(),
        AppRoutes.saleDetail: (context) => const SaleDetailScreen(),
        AppRoutes.voidCard: (context) => const VoidCardScreen(),
        AppRoutes.voidStatus: (context) => const VoidResultScreen(),
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.loading: (context) => const LoadingScreen(),
      },
    );
  }
}
