import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'payment_option_card.dart';

class SelectNewOperationContent extends StatelessWidget {
  final VoidCallback onCardTap;
  final VoidCallback onManualCardTap;

  const SelectNewOperationContent({
    super.key,
    required this.onCardTap,
    required this.onManualCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título paso 1
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Seleccioná el modo de pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Elegí cómo desea pagar tu cliente.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Opción 1: Tarjeta
          PaymentOptionCard(
            icon: Icons.credit_card,
            title: 'Tarjeta',
            subtitle: 'Acercar, insertar\no deslizar',
            onTap: onCardTap,
          ),
          const SizedBox(height: 12),

          // Opción 2: QR (aún no disponible)
          PaymentOptionCard(
            icon: Icons.qr_code_2,
            title: 'QR',
            subtitle: 'Generar código QR\npara el pago',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El pago con QR estará disponible pronto.'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Opción 3: Ingreso manual
          PaymentOptionCard(
            icon: Icons.grid_view_rounded,
            title: 'Ingreso manual',
            subtitle: 'Ingresar datos de\ntarjeta manualmente',
            onTap: onManualCardTap,
          ),
          const SizedBox(height: 20),

          // Banner de seguridad
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.security, color: Colors.black54),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Todos los pagos son procesados de forma segura.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón Cancelar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppColors.primaryOrange,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // Acción de cancelar (ej. Navigator.pop(context))
                Navigator.maybePop(context);
              },
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
