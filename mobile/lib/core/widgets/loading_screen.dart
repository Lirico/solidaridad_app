import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreAndRoute());
    });
  }

  Future<void> _restoreAndRoute() async {
    final cubit = context.read<AuthCubit>();
    await cubit.restore();
    if (!mounted) return;
    final state = cubit.state;
    if (state is AuthSuccess && state.mustChangePassword) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.changePassword,
        arguments: <String, dynamic>{'isFirstLogin': true},
      );
      return;
    }
    if (state is AuthSuccess) {
      Navigator.pushReplacementNamed(context, AppRoutes.saleForm);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Iniciando',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
