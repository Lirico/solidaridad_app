import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../cubit/sales_cubit.dart';
import '../widgets/manual_card_content.dart';

class SaleManualCardScreen extends StatefulWidget {
  const SaleManualCardScreen({super.key});

  @override
  State<SaleManualCardScreen> createState() => _SaleManualCardScreenState();
}

class _SaleManualCardScreenState extends State<SaleManualCardScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_formKey.currentState!.validate()) {
      final cubit = context.read<SalesCubit>();
      final state = cubit.state;

      cubit.showReview(
        productCode: state.productCode,
        productLabel: state.productLabel,
        amount: state.amount,
        cardNumber: _cardNumberController.text,
        cvv: _cvvController.text,
        expirationDate: _expiryController.text.replaceAll('/', ''),
        entryMode: '012',
      );

      Navigator.pushNamed(context, AppRoutes.saleReview);
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
          child: ManualCardContent(
            cardNumberController: _cardNumberController,
            expiryController: _expiryController,
            cvvController: _cvvController,
            onContinue: _onContinue,
          ),
        ),
      ),
    );
  }
}
