import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../sales/presentation/widgets/sale_review_widgets.dart';

class BalanceReviewContent extends StatelessWidget {
  final String cardNumber;
  final VoidCallback onConfirm;

  const BalanceReviewContent({
    super.key,
    required this.cardNumber,
    required this.onConfirm,
  });

  String _maskCardNumber(String cardNumber) {
    final digits = cardNumber.replaceAll(' ', '');
    if (digits.length < 4) return '•••• •••• •••• 4321';
    return '•••• •••• •••• ${digits.substring(digits.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Verifique la tarjeta antes de consultar el saldo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        ReviewDataRow(
          icon: Icons.credit_card_outlined,
          label: 'Tarjeta',
          value: cardNumber.isEmpty
              ? '•••• •••• •••• 4321'
              : _maskCardNumber(cardNumber),
        ),
        const SizedBox(height: 56),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'CONSULTAR SALDO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
