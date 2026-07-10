import 'package:flutter/material.dart';

class SaleStatusScreen extends StatelessWidget {
  // Ya no necesitamos la propiedad final obligatoria en el constructor,
  // la leemos dinámicamente de la ruta.
  const SaleStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Capas de atrapar el argumento enviado por el Navigator (true o false)
    final bool isSuccess =
        (ModalRoute.of(context)?.settings.arguments as bool?) ?? true;

    final Color statusColor = isSuccess
        ? const Color(0xFF2ECC71)
        : const Color(0xFFE74C3C);
    final IconData statusIcon = isSuccess
        ? Icons.check_circle_outline
        : Icons.error_outline;
    final String statusTitle = isSuccess
        ? '¡Transacción Aprobada!'
        : 'Transacción Rechazada';
    final String statusSubtitle = isSuccess
        ? 'El mensaje ISO fue procesado con éxito por AWS.'
        : 'La terminal reportó un error en la autorización.';

    // ... EL RESTO DEL CÓDIGO DEL TICKET SIGUE EXACTAMENTE IGUAL ...

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- CABECERA AZUL INSTITUCIONAL ---
            Container(
              width: double.infinity,
              height: 180,
              color: const Color(0xFF1A4F9C),
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Resultado del Cobro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENEDOR FLOTANTE BLANCO (ESTADO) ---
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Ícono gigante animado por color
                        Icon(statusIcon, size: 100, color: statusColor),
                        const SizedBox(height: 24),

                        // Título del estado
                        Text(
                          statusTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtítulo explicativo
                        Text(
                          statusSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Recuadro gris con datos del ticket de la operación
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: Column(
                            children: [
                              _buildTicketRow('Terminal ID', 'TERM-00432'),
                              const Divider(height: 20),
                              _buildTicketRow(
                                'Nro. Operación',
                                isSuccess ? 'OP-987452' : '---',
                              ),
                              const Divider(height: 20),
                              _buildTicketRow(
                                'Código Respuesta',
                                isSuccess ? '00 (OK)' : '51 (Fondos Insuf.)',
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Botón de cierre: resetea el flujo y vuelve al formulario vacío
                        ElevatedButton(
                          onPressed: () {
                            // Sacamos todas las pantallas del historial y volvemos a la de ventas limpia
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/sales_form',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A4F9C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'FINALIZAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pequeño helper inline para armar las filas del ticket interno
  Widget _buildTicketRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
