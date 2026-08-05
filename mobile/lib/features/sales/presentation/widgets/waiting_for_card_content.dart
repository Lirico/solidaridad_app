import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'waiting_for_card_reader_graphic.dart';

class WaitingForCardContent extends StatelessWidget {
  final VoidCallback? onCancelOperation;
  final VoidCallback? onChangePaymentMode;

  const WaitingForCardContent({
    super.key,
    this.onCancelOperation,
    this.onChangePaymentMode,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paso 1: Modo de pago (ya completado, se muestra como resumen)
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
              const SizedBox(width: 12),
              const Text(
                'Modo de pago',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Resumen de la tarjeta seleccionada
          Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.credit_card,
                      color: AppColors.primaryOrange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Tarjeta',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Acercar, insertar o deslizar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.iconGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed:
                      onChangePaymentMode ?? () => Navigator.maybePop(context),
                  child: const Text(
                    'Cambiar',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 24),

          // Paso 2: Esperando tarjeta
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
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Esperando tarjeta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 40.0),
            child: Text(
              'Acercá, insertá o deslizá la tarjeta\nen el dispositivo',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 32),

          // Gráfico central: Lector de tarjetas y mano
          const WaitingForCardReaderGraphic(),
          const SizedBox(height: 48),

          // Banner de información
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(
                    Icons.info_outline,
                    color: AppColors.primaryOrange,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Podés usar tarjeta con chip, banda magnética o sin contacto (NFC).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Botón Cancelar Operación
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
              onPressed: onCancelOperation ?? () {},
              child: const Text(
                'CANCELAR OPERACIÓN',
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
