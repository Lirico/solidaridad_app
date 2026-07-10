import 'package:flutter/material.dart';

// --- WIDGET 1: FILA DE DATOS DEL RESUMEN ---
class ReviewDataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ReviewDataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A4F9C), size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- WIDGET 2: VISTA DE PROCESAMIENTO / LOADING ---
class ProcessingTransactionView extends StatelessWidget {
  const ProcessingTransactionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A4F9C)),
        ),
        SizedBox(height: 24),
        Text(
          'Procesando Transacción...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Enviando mensaje ISO de seguridad a AWS. Por favor, no cierre la aplicación.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }
}
