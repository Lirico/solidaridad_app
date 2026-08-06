import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'card_fields_container.dart';

class ManualCardContent extends StatelessWidget {
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final VoidCallback onContinue;

  const ManualCardContent({
    super.key,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingresá los datos de la tarjeta de crédito.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          CardFieldsContainer(
            cardNumberController: cardNumberController,
            expiryController: expiryController,
            cvvController: cvvController,
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
