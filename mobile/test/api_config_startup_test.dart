import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/core/config/api_config.dart';
import 'package:solidaridad_app/core/widgets/splash_screen.dart';
import 'package:solidaridad_app/features/auth/presentation/screens/login_screen.dart';
import 'package:solidaridad_app/main.dart';

void main() {
  ApiConfigResolution releaseDecision(String fromDefine) {
    return ApiConfig.resolve(
      fromDefine: fromDefine,
      releaseMode: true,
      isWeb: false,
      isAndroid: true,
    );
  }

  testWidgets('release sin servidor muestra el error y no abre el login', (
    tester,
  ) async {
    startApp(releaseDecision(''));
    await tester.pump();

    expect(find.text(ApiConfig.releaseMissingUrlError), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('INGRESAR'), findsNothing);
    expect(find.text('ejemplo@gas.com'), findsNothing);
  });

  testWidgets('release con HTTP muestra el error y no abre el login', (
    tester,
  ) async {
    startApp(releaseDecision('http://api.example/v1'));
    await tester.pump();

    expect(find.text(ApiConfig.releaseHttpError), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('INGRESAR'), findsNothing);
    expect(find.text('ejemplo@gas.com'), findsNothing);
  });

  testWidgets('con URL https el arranque sigue al splash', (tester) async {
    startApp(releaseDecision('https://api.example/v1'));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('INGRESAR'), findsNothing);
    expect(find.text(ApiConfig.releaseMissingUrlError), findsNothing);
    expect(find.text(ApiConfig.releaseHttpError), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
