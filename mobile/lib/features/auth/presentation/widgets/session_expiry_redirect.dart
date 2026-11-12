import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Vuelve al login cuando la API rechaza el token guardado.
class SessionExpiryRedirect extends StatelessWidget {
  const SessionExpiryRedirect({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSessionExpired && previous is! AuthSessionExpired,
      listener: (context, state) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      },
      child: child,
    );
  }
}
