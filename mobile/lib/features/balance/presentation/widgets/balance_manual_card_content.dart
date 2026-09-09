import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/formatters/card_formatters.dart';
import '../../../../core/theme/app_colors.dart';

/// Captura manual de tarjeta para consulta de saldo: PAN + vencimiento.
///
/// Replica la visual de [CardFieldsContainer] (mismo contenedor "Datos de
/// Tarjeta") pero sin CVV, porque la consulta de saldo (0100) no lo requiere.
class BalanceManualCardContent extends StatelessWidget {
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final VoidCallback onContinue;

  const BalanceManualCardContent({
    super.key,
    required this.cardNumberController,
    required this.expiryController,
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
            'Ingresá los datos de la tarjeta.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos de Tarjeta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cardNumberController,
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CardNumberFormatter(),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Número de Tarjeta',
                    prefixIcon: Icon(Icons.credit_card),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El número es obligatorio';
                    }
                    final cleanNumber = value.replaceAll(' ', '');
                    if (cleanNumber.length < 15 || cleanNumber.length > 16) {
                      return 'Debe tener entre 15 y 16 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: expiryController,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CardExpiryFormatter(),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'MM/AA',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Obligatorio';
                    }
                    if (!value.contains('/') || value.length != 5) {
                      return 'Formato inválido';
                    }
                    final parts = value.split('/');
                    final month = int.tryParse(parts[0]) ?? 0;
                    if (month < 1 || month > 12) {
                      return 'Mes inválido';
                    }
                    return null;
                  },
                ),
              ],
            ),
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
