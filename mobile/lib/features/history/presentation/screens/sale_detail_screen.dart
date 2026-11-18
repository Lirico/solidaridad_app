import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/data/receipt_printer.dart';
import '../../../sales/domain/receipt_defaults.dart';
import '../../../sales/domain/sale_model.dart';
import '../widgets/sale_detail_ticket.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, this.printer});

  final ReceiptPrinter? printer;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late final ReceiptPrinter _printer = widget.printer ?? ReceiptPrinter();
  ReceiptDefaults? _defaults;
  bool _defaultsFailed = false;
  bool _printing = false;
  bool _loadedDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    _loadedDefaults = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! OperationModel) return;
    _defaults = _defaultsFor(args);
    _defaultsFailed = _defaults == null;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! OperationModel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: Text('No hay datos de la operación disponibles')),
      );
    }

    final operation = args;
    final bool canVoid = operation.result == PaymentResult.approved;
    final bool canPrint =
        operation.result == PaymentResult.approved ||
        operation.result == PaymentResult.underReview ||
        operation.result == PaymentResult.declined;

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Detalle de Comprobante',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: _buildTicket(operation),
                ),
              ),
            ),
            if (canPrint) _buildPrintButton(context, operation),
            if (canVoid) _buildVoidButton(context, operation),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(OperationModel operation) {
    final defaults = _defaults;
    if (defaults != null) {
      return SaleDetailTicket(operation: operation, defaults: defaults);
    }
    if (_defaultsFailed) {
      return const Text('No se pudieron cargar los datos del comprobante.');
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildPrintButton(BuildContext context, OperationModel operation) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _printing ? null : () => _printTicket(operation),
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            label: Text(
              _printing ? 'IMPRIMIENDO...' : 'IMPRIMIR TICKET',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  ReceiptDefaults? _defaultsFor(OperationModel operation) {
    final merchant = context.read<AuthCubit>().merchant;
    if (merchant == null) return null;
    return ReceiptDefaults.forSale(
      merchantCode: merchant.code,
      merchantName: merchant.name,
      merchantAddress: merchant.address,
      merchantCity: merchant.city,
      merchantTaxId: merchant.taxId,
      operation: operation,
    );
  }

  String _missingMerchantMessage() =>
      'La cuenta no tiene un comercio configurado.';

  Future<void> _printTicket(OperationModel operation) async {
    setState(() => _printing = true);
    final defaults = _defaultsFor(operation);
    if (defaults == null) {
      setState(() => _printing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_missingMerchantMessage()),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _defaults = defaults);
    final PrintResult result = await _printer.printTicket(
      operation,
      defaults: defaults,
    );
    if (!mounted) return;
    setState(() => _printing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok
            ? AppColors.primaryOrange
            : Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildVoidButton(BuildContext context, OperationModel operation) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmVoid(context, operation),
            icon: const Icon(Icons.undo),
            label: const Text(
              'ANULAR VENTA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    OperationModel operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Anular venta'),
          content: Text(
            '¿Seguro que querés anular la venta ${operation.id}?\n'
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Sí, anular',
                style: TextStyle(color: AppColors.primaryOrange),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    Navigator.pushNamed(context, AppRoutes.voidCard, arguments: operation);
  }
}
