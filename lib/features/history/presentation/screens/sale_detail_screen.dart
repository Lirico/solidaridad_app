import 'package:flutter/material.dart';
import '../../data/models/operation_model.dart';
import '../widgets/sale_detail_ticket.dart'; // 👑 NUEVO IMPORT

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Recibimos la operación por los argumentos de la ruta nativa
    final operation =
        ModalRoute.of(context)!.settings.arguments as OperationModel;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F6F9,
      ), // Unificamos el fondo gris claro
      appBar: AppBar(
        title: const Text(
          'Detalle de Comprobante',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A4F9C), // Mismo azul institucional
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            // 👑 CONTENIDO TOTALMENTE MODULARIZADO
            child: SaleDetailTicket(operation: operation),
          ),
        ),
      ),
    );
  }
}
