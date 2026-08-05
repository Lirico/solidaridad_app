import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Gráfico central del lector de tarjetas con la mano sosteniendo la tarjeta.
class WaitingForCardReaderGraphic extends StatelessWidget {
  const WaitingForCardReaderGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Lector de tarjetas (icono estilizado)
          Container(
            margin: const EdgeInsets.only(right: 40),
            width: 150,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF303030),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.wifi,
                      size: 60,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212121),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          // Mano sosteniendo la tarjeta (fallback ilustrativo)
          Transform.translate(
            offset: const Offset(0, 20),
            child: Container(
              width: 100,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Center(
                child: Icon(
                  Icons.credit_card,
                  size: 48,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
