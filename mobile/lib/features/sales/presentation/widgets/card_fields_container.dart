import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/formatters/card_formatters.dart';

class CardFieldsContainer extends StatelessWidget {
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final TextEditingController cardHolderController;

  const CardFieldsContainer({
    super.key,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    required this.cardHolderController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: Color(0xFF1A4F9C),
            ),
          ),
          const SizedBox(height: 12),

          // --- NÚMERO DE TARJETA CON VALIDACIÓN NATIVA ---
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
              // Quitamos los espacios de la máscara para evaluar los dígitos puros
              final cleanNumber = value.replaceAll(' ', '');
              if (cleanNumber.length < 15 || cleanNumber.length > 16) {
                return 'Debe tener entre 15 y 16 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment
                .start, // Evita que los errores desalineen la fila
            children: [
              // --- VENCIMIENTO TARJETA ---
              Expanded(
                child: TextFormField(
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
                    // Validamos que el mes sea coherente (01 a 12)
                    final parts = value.split('/');
                    final month = int.tryParse(parts[0]) ?? 0;
                    if (month < 1 || month > 12) {
                      return 'Mes inválido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),

              // --- CÓDIGO CVV ---
              Expanded(
                child: TextFormField(
                  controller: cvvController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Código CVV',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Obligatorio';
                    }
                    if (value.length < 3 || value.length > 4) {
                      return '3 o 4 dígitos';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- TITULAR DE LA TARJETA ---
          TextFormField(
            controller: cardHolderController,
            textCapitalization: TextCapitalization
                .characters, // Fuerza mayúsculas para estética bancaria
            decoration: const InputDecoration(
              hintText: 'Nombre del Titular',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre del titular es obligatorio';
              }
              if (value.trim().split(' ').length < 2) {
                return 'Ingrese nombre y apellido completo';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
