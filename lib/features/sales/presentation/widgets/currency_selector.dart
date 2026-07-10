import 'package:flutter/material.dart';

class CurrencySelector extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged; // El "onChange" de React

  const CurrencySelector({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Especie / Moneda',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onCurrencyChanged('ARS'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: selectedCurrency == 'ARS'
                        ? const Color(0xFF1A4F9C)
                        : const Color(0xFFCED4DA),
                    width: selectedCurrency == 'ARS' ? 2 : 1,
                  ),
                  backgroundColor: selectedCurrency == 'ARS'
                      ? const Color(0xFF1A4F9C).withValues(alpha: 0.05)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'ARS',
                  style: TextStyle(
                    color: selectedCurrency == 'ARS'
                        ? const Color(0xFF1A4F9C)
                        : Colors.black87,
                    fontWeight: selectedCurrency == 'ARS'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onCurrencyChanged('USD'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: selectedCurrency == 'USD'
                        ? const Color(0xFF1A4F9C)
                        : const Color(0xFFCED4DA),
                    width: selectedCurrency == 'USD' ? 2 : 1,
                  ),
                  backgroundColor: selectedCurrency == 'USD'
                      ? const Color(0xFF1A4F9C).withValues(alpha: 0.05)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'USD',
                  style: TextStyle(
                    color: selectedCurrency == 'USD'
                        ? const Color(0xFF1A4F9C)
                        : Colors.black87,
                    fontWeight: selectedCurrency == 'USD'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
