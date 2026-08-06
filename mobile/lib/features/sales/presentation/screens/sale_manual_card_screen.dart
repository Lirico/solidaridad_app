import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../cubit/sales_cubit.dart';
import '../widgets/manual_card_content.dart';
import '../widgets/manual_card_header.dart';

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
      );

      Navigator.pushNamed(context, AppRoutes.saleReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: ManualCardHeader(
        onBackPressed: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ManualCardContent(
              cardNumberController: _cardNumberController,
              expiryController: _expiryController,
              cvvController: _cvvController,
              onContinue: _onContinue,
            ),
          ),
        ),
      ),
    );
  }
}
