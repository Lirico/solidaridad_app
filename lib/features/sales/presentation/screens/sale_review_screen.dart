import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';
import '../widgets/sale_review_widgets.dart';

class SaleReviewScreen extends StatefulWidget {
  const SaleReviewScreen({super.key});

  @override
  State<SaleReviewScreen> createState() => _SaleReviewScreenState();
}

class _SaleReviewScreenState extends State<SaleReviewScreen> {
  bool _isProcessing = false;

  void _onConfirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    final salesCubit = context.read<SalesCubit>();
    await salesCubit.sendIsoMessage();

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    final finalState = salesCubit.state;
    final bool success = finalState is SalesSuccess;

    Navigator.pushReplacementNamed(context, '/sale_status', arguments: success);
  }

  @override
  Widget build(BuildContext context) {
    final salesState = context.watch<SalesCubit>().state;

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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Confirmar Operación',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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
                    child: _isProcessing
                        ? const ProcessingTransactionView()
                        : _buildReviewContent(salesState),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTENIDO DEL RESUMEN DE COMPRA ---
  Widget _buildReviewContent(SalesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Verifique los datos antes de proceder al cobro en la terminal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),

        // Ahora lee directamente lo que guardaste en el formulario
        ReviewDataRow(
          icon: Icons.monetization_on_outlined,
          label: 'Moneda de Cobro',
          value: state.currency,
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.local_gas_station_outlined,
          label: 'Cantidad de Gas',
          value: '${state.amount} m³',
        ),
        const Divider(height: 32),

        ReviewDataRow(
          icon: Icons.credit_card_outlined,
          label: 'Tarjeta Destino',
          value: state.cardNumber.isEmpty
              ? '•••• •••• •••• 4321'
              : state.cardNumber,
        ),
        const Spacer(),

        // Botón Principal de Confirmación
        ElevatedButton(
          onPressed: _onConfirmPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE67E22),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            'CONFIRMAR COBRO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
