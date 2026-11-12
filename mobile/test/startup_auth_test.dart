import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/core/constants/app_routes.dart';
import 'package:solidaridad_app/core/widgets/loading_screen.dart';
import 'package:solidaridad_app/core/widgets/splash_screen.dart';

void main() {
  testWidgets('un arranque nuevo siempre termina en login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.loading: (_) => const LoadingScreen(),
          AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
        },
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(LoadingScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
