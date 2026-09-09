import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/presentation/widgets/payment_option_card.dart';

class BalanceCaptureModeScreen extends StatelessWidget {
  const BalanceCaptureModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Consultar Saldo',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Seleccioná el modo de captura',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Elegí cómo leer la tarjeta para consultar el saldo.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              PaymentOptionCard(
                icon: Icons.credit_card,
                title: 'Tarjeta',
                subtitle: 'Acercar, insertar\no deslizar',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.balanceWaitingForCard,
                ),
              ),
              const SizedBox(height: 12),
              PaymentOptionCard(
                icon: Icons.grid_view_rounded,
                title: 'Ingreso manual',
                subtitle: 'Ingresar datos de\ntarjeta manualmente',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.balanceManualCard,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.primaryOrange,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
