import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/receipt_printer.dart';
import '../../domain/sale_model.dart';
import '../widgets/sale_review_header.dart';
import '../widgets/sale_status_content.dart';

class SaleStatusScreen extends StatefulWidget {
  const SaleStatusScreen({super.key});

  @override
  State<SaleStatusScreen> createState() => _SaleStatusScreenState();
}

class _SaleStatusScreenState extends State<SaleStatusScreen> {
  final ReceiptPrinter _printer = ReceiptPrinter();
  OperationModel? _operation;
  PrintStatus _printStatus = PrintStatus.idle;
  String _printMessage = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies puede ejecutarse varias veces; solo inicializamos
    // una vez. ModalRoute.of(context) no puede llamarse en initState() porque
    // usa dependOnInheritedWidgetOfExactType, prohibido antes del montaje.
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is OperationModel) {
      _operation = args;
      // Impresión automática al aprobar la venta.
      if (args.result == PaymentResult.approved) {
        _printTicket();
      }
    }
  }

  Future<void> _printTicket() async {
    final operation = _operation;
    if (operation == null) return;

    setState(() {
      _printStatus = PrintStatus.printing;
      _printMessage = '';
    });

    final PrintResult result = await _printer.printTicket(operation);

    if (!mounted) return;
    setState(() {
      _printStatus = result.ok ? PrintStatus.printed : PrintStatus.error;
      _printMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final OperationModel? operation = _operation;
    final PaymentResult result = operation?.result ?? PaymentResult.approved;

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    switch (result) {
      case PaymentResult.approved:
        statusColor = const Color(0xFF2ECC71);
        statusIcon = Icons.check_circle_outline;
        statusTitle = '¡Transacción Aprobada!';
        statusSubtitle = 'El pago fue autorizado correctamente.';
      case PaymentResult.declined:
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.error_outline;
        statusTitle = 'Transacción Rechazada';
        statusSubtitle = 'La terminal reportó un error en la autorización.';
      case PaymentResult.connectionError:
        statusColor = const Color(0xFFFF8C00);
        statusIcon = Icons.wifi_off_outlined;
        statusTitle = 'Error de Conexión';
        statusSubtitle =
            'No se pudo contactar con el procesador. Verifique su conectividad y reintente.';
      case PaymentResult.voided:
        statusColor = Colors.grey;
        statusIcon = Icons.undo;
        statusTitle = 'Transacción Anulada';
        statusSubtitle = 'La venta fue anulada correctamente.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sin botón de volver: la acción de salida es FINALIZAR
            const SaleReviewHeader(title: 'Resultado del Cobro'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                  child: SaleStatusContent(
                    result: result,
                    statusColor: statusColor,
                    statusIcon: statusIcon,
                    statusTitle: statusTitle,
                    statusSubtitle: statusSubtitle,
                    operation: operation,
                    printStatus: _printStatus,
                    printMessage: _printMessage,
                    onRetryPrint: result == PaymentResult.approved
                        ? _printTicket
                        : null,
                    onFinalize: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.saleForm,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
