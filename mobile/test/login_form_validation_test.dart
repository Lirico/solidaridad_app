import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/auth/data/auth_repository.dart';
import 'package:solidaridad_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:solidaridad_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets(
    'el error del usuario desaparece al corregir el campo sin reenviar',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1440);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => AuthCubit(authRepository: AuthRepository()),
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('INGRESAR'));
      await tester.pump();

      expect(find.text('El usuario o correo es obligatorio'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'comercio');
      await tester.pump();

      expect(find.text('El usuario o correo es obligatorio'), findsNothing);
    },
  );
}
