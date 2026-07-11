import 'package:flutter/material.dart';

class CurrencySelector extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;

  static final _currencies = ['ARS', 'USD'];
  static const _primaryColor = Color(0xFF1A4F9C);

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
          children: _currencies.map((currency) {
            final isSelected = selectedCurrency == currency;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: currency == _currencies.first ? 0 : 6,
                  right: currency == _currencies.last ? 0 : 6,
                ),
                child: OutlinedButton(
                  onPressed: () => onCurrencyChanged(currency),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isSelected
                          ? _primaryColor
                          : const Color(0xFFCED4DA),
                      width: isSelected ? 2 : 1,
                    ),
                    backgroundColor: isSelected
                        ? _primaryColor.withValues(alpha: 0.05)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    currency,
                    style: TextStyle(
                      color: isSelected ? _primaryColor : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
