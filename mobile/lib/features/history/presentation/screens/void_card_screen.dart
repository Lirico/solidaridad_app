import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/cubit/sales_cubit.dart';
import '../../../sales/presentation/widgets/card_fields_container.dart';

class VoidCardScreen extends StatefulWidget {
  const VoidCardScreen({super.key});

  @override
  State<VoidCardScreen> createState() => _VoidCardScreenState();
}

class _VoidCardScreenState extends State<VoidCardScreen> {
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

  Future<void> _onContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! OperationModel) return;

    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthSuccess ? authState.user : null;
    if (user == null) return;

    final cardNumber = _cardNumberController.text;
    final expiration = _expiryController.text.replaceAll('/', '');

    final voidResult = await context.read<SalesCubit>().voidSale(
      token: user.token,
      transactionNumber: args.id,
      cardNumber: cardNumber,
      expirationDate: expiration.isEmpty ? null : expiration,
    );

    if (!mounted) return;

    if (voidResult.sessionExpired) {
      context.read<AuthCubit>().logout();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.voidStatus,
      arguments: voidResult,
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! OperationModel) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Anular venta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primaryOrange,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: const Center(child: Text('Error: datos de operación no disponibles')),
      );
    }

    final operation = args;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Anular venta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0C987)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anulando venta ${operation.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${operation.productLabel} — '
                        '${operation.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reingresá los datos de la tarjeta usada en la venta.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                CardFieldsContainer(
                  cardNumberController: _cardNumberController,
                  expiryController: _expiryController,
                  cvvController: _cvvController,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ANULAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
