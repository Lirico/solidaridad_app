import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../cubit/balance_cubit.dart';
import '../widgets/balance_manual_card_content.dart';

class BalanceManualCardScreen extends StatefulWidget {
  const BalanceManualCardScreen({super.key});

  @override
  State<BalanceManualCardScreen> createState() => _BalanceManualCardScreenState();
}

class _BalanceManualCardScreenState extends State<BalanceManualCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_formKey.currentState!.validate()) {
      context.read<BalanceCubit>().setCardData(
        cardNumber: _cardNumberController.text,
        expirationDate: _expiryController.text.replaceAll('/', ''),
        entryMode: '012',
      );
      Navigator.pushNamed(context, AppRoutes.balanceReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Ingreso Manual',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: Form(
          key: _formKey,
          child: BalanceManualCardContent(
            cardNumberController: _cardNumberController,
            expiryController: _expiryController,
            onContinue: _onContinue,
          ),
        ),
      ),
    );
  }
}
