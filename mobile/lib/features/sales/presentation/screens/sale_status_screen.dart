import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../data/receipt_printer.dart';
import '../../domain/sale_model.dart';
import '../cubit/sales_cubit.dart';
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
  bool _reportedMissingData = false;

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
      // El comercio recibe un comprobante tanto de una aprobación como de una
      // verificación manual; el segundo nunca afirma un resultado financiero.
      if (args.result == PaymentResult.approved ||
          args.result == PaymentResult.underReview) {
        _printTicket();
      }
    }
  }

  void _retrySale(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final token = authState is AuthSuccess ? authState.user!.token : '';
    context.read<SalesCubit>().sendIsoMessage(token: token);
    Navigator.pushNamed(context, AppRoutes.saleProcessing);
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
    // Sin datos no se asume aprobada: es el mismo criterio que el detalle.
    if (operation == null) {
      if (_initialized && !_reportedMissingData) {
        _reportedMissingData = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.maybePop(context);
        });
      }
      return const Scaffold(
        body: Center(child: Text('No hay datos de la operación disponibles')),
      );
    }

    final PaymentResult result = operation.result;
    final serverMessage = operation.userMessage?.trim();
    String withServerMessage(String fallback) =>
        (serverMessage != null && serverMessage.isNotEmpty)
        ? serverMessage
        : fallback;

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    switch (result) {
      case PaymentResult.approved:
        statusColor = const Color(0xFF2ECC71);
        statusIcon = Icons.check_circle_outline;
        statusTitle = '¡Transacción Aprobada!';
        statusSubtitle = 'La descarga fue autorizada correctamente.';
      case PaymentResult.declined:
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.error_outline;
        statusTitle = 'Transacción Rechazada';
        statusSubtitle = withServerMessage(
          'La terminal reportó un error en la autorización.',
        );
      case PaymentResult.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusTitle = 'Transacción en Proceso';
        statusSubtitle = withServerMessage(
          'La autorización sigue en curso.',
        );
      case PaymentResult.underReview:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.manage_search;
        statusTitle = 'Verificación requerida';
        statusSubtitle =
            'Verifique la operación con casa central. La descarga podría haberse procesado.';
      case PaymentResult.failed:
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.error_outline;
        statusTitle = 'Error de Autorización';
        statusSubtitle = withServerMessage(
          'No fue posible completar la autorización.',
        );
      case PaymentResult.connectionError:
        statusColor = const Color(0xFFFF8C00);
        statusIcon = Icons.wifi_off_outlined;
        statusTitle = 'Error de Conexión';
        statusSubtitle = withServerMessage(
          'No se pudo contactar con el procesador. Verifique su conectividad y reintente.',
        );
      case PaymentResult.voided:
        statusColor = Colors.grey;
        statusIcon = Icons.undo;
        statusTitle = 'Transacción Anulada';
        statusSubtitle = 'La venta fue anulada correctamente.';
    }

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Resultado de la Descarga',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      // Sin flecha atrás: la salida es FINALIZAR / VENTA / ⋯.
      bottomNavigationBar: const AppBottomNavBar(hideBack: true),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SaleStatusContent(
            result: result,
            statusColor: statusColor,
            statusIcon: statusIcon,
            statusTitle: statusTitle,
            statusSubtitle: statusSubtitle,
            operation: operation,
            printStatus: _printStatus,
            printMessage: _printMessage,
            onRetryPrint:
                result == PaymentResult.approved ||
                    result == PaymentResult.underReview
                ? _printTicket
                : null,
            onRetry: result == PaymentResult.connectionError
                ? () => _retrySale(context)
                : null,
            finalizeLabel: result == PaymentResult.underReview
                ? 'NUEVA VENTA'
                : 'FINALIZAR',
            onFinalize: () {
              if (result == PaymentResult.underReview) {
                context.read<SalesCubit>().startNewSaleAfterReview();
              }
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.saleForm,
                (route) => false,
              );
            },
          ),
        ),
      ),
    );
  }
}
