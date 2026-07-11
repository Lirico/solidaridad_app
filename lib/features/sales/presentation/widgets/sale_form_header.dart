import 'package:flutter/material.dart';

class SaleFormHeader extends StatelessWidget {
  const SaleFormHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFF1A4F9C),
      padding: const EdgeInsets.only(top: 60, left: 24, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Nueva Operación',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.lock_reset,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Cambiar Contraseña',
                onPressed: () {
                  Navigator.pushNamed(context, '/change_password');
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white, size: 28),
                tooltip: 'Ver historial de ventas',
                onPressed: () {
                  Navigator.pushNamed(context, '/sales_history');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
