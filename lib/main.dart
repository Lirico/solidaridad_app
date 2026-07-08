import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Importaciones de tu Feature de Ventas
import 'features/sales/data/sales_repository.dart';
import 'features/sales/presentation/cubit/sales_cubit.dart';
import 'features/sales/presentation/screens/sale_form_screen.dart';

// Importación de tu tema global
import 'core/theme/app_theme.dart';

void main() {
  // Aquí inicializás tus servicios/repositorios (Tus instancias globales)
  final salesRepository = SalesRepository();

  runApp(
    // Envolvemos toda la aplicación con el Provider para inyectar el Cubit
    BlocProvider<SalesCubit>(
      create: (context) => SalesCubit(salesRepository),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Solidaridad',
      debugShowCheckedModeBanner: false,

      // Aquí conectás el archivo de estilos que armaste en /core/theme
      theme:
          appTheme, // O como hayas nombrado a la variable ThemeData en tu archivo
      // Definimos la pantalla inicial de la Fase 0 (El formulario de venta)
      home: const SaleFormScreen(),
    );
  }
}
