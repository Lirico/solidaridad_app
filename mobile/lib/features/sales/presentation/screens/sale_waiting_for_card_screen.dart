import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/waiting_for_card_bottom_bar.dart';
import '../widgets/waiting_for_card_content.dart';
import '../widgets/waiting_for_card_header.dart';

class WaitingForCardScreen extends StatelessWidget {
  const WaitingForCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const WaitingForCardHeader(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Contenido principal blanco con bordes redondeados
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: const WaitingForCardContent(),
            ),
          ),
          // Botón Volver fijo en la parte inferior (fuera del contenedor blanco)
          const WaitingForCardBottomBar(),
        ],
      ),
    );
  }
}
