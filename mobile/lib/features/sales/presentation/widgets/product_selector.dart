import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/sale_model.dart';

class ProductSelector extends StatelessWidget {
  final List<ProductInfo> products;
  final String selectedCode;
  final ValueChanged<String> onProductChanged;

  const ProductSelector({
    super.key,
    required this.products,
    required this.selectedCode,
    required this.onProductChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Producto / Especie',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...products.map((product) {
          final isSelected = selectedCode == product.code;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => onProductChanged(product.code),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : const Color(0xFFCED4DA),
                  width: isSelected ? 2 : 1,
                ),
                backgroundColor: isSelected
                    ? AppColors.primaryOrange.withValues(alpha: 0.05)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  product.label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
