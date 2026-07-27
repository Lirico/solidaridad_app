import 'package:flutter/material.dart';
import '../../domain/sale_model.dart';

class ProductSelector extends StatefulWidget {
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
  State<ProductSelector> createState() => _ProductSelectorState();
}

class _ProductSelectorState extends State<ProductSelector> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.selectedCode;
  }

  @override
  void didUpdateWidget(covariant ProductSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCode != oldWidget.selectedCode) {
      _selectedCode = widget.selectedCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCode,
      isExpanded: true,
      items: widget.products.map((product) {
        return DropdownMenuItem<String>(
          value: product.code,
          child: Text(product.label),
        );
      }).toList(),
      onChanged: (code) {
        if (code != null) {
          setState(() {
            _selectedCode = code;
          });
          widget.onProductChanged(code);
        }
      },
      decoration: const InputDecoration(
        labelText: 'Producto / Especie',
        prefixIcon: Icon(Icons.propane_tank_outlined),
      ),
      selectedItemBuilder: (context) {
        return widget.products.map<Widget>((product) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              product.label,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          );
        }).toList();
      },
    );
  }
}
