import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/data/product_catalog_store.dart';
import '../../../sales/data/receipt_printer.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/receipt_defaults.dart';
import '../../../sales/domain/sale_model.dart';
import '../../domain/balance_product_quantities.dart';
import '../../domain/balance_model.dart';
import '../cubit/balance_cubit.dart';
import '../cubit/balance_state.dart';
import '../widgets/balance_status_content.dart';

class BalanceStatusScreen extends StatefulWidget {
  final ReceiptPrinter? printer;
  final ProductCatalogStore? productCatalogStore;

  const BalanceStatusScreen({
    super.key,
    this.printer,
    this.productCatalogStore,
  });

  @override
  State<BalanceStatusScreen> createState() => _BalanceStatusScreenState();
}

class _BalanceStatusScreenState extends State<BalanceStatusScreen> {
  late final ReceiptPrinter _printer = widget.printer ?? ReceiptPrinter();
  PrintStatus _printStatus = PrintStatus.idle;
  String _printMessage = '';
  bool _started = false;
  DateTime? _printedAt;
  List<ProductInfo> _products = const <ProductInfo>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final state = context.read<BalanceCubit>().state;
    if (state is! BalanceCompleted) return;
    if (state.result.status != BalanceStatus.approved) return;
    _printedAt = DateTime.now();
    _printTicket();
  }

  Future<void> _printTicket() async {
    final state = context.read<BalanceCubit>().state;
    if (state is! BalanceCompleted) return;
    final date = _printedAt ?? DateTime.now();

    setState(() {
      _printStatus = PrintStatus.printing;
      _printMessage = '';
    });

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthSuccess || authState.user == null) {
      setState(() {
        _printStatus = PrintStatus.error;
        _printMessage = 'No hay una sesión activa para cargar los productos.';
      });
      return;
    }

    final List<ProductInfo> products;
    try {
      products =
          await (widget.productCatalogStore ??
                  context.read<ProductCatalogStore>())
              .getOrLoad(token: authState.user!.token);
    } on SessionExpiredException {
      if (!mounted) return;
      context.read<AuthCubit>().logout();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
      return;
    } on DataLoadException catch (error) {
      if (!mounted) return;
      setState(() {
        _printStatus = PrintStatus.error;
        _printMessage = error.message;
      });
      return;
    }

    final List<ProductQuantity> balances;
    try {
      balances = balanceProductQuantities(state.result.balances, products);
    } on StateError {
      if (!mounted) return;
      setState(() {
        _printStatus = PrintStatus.error;
        _printMessage =
            'El catálogo de productos no coincide con el saldo consultado.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _products = products);

    final defaults = _receiptDefaults();
    if (defaults == null) {
      setState(() {
        _printStatus = PrintStatus.error;
        _printMessage = 'La cuenta no tiene un comercio configurado.';
      });
      return;
    }

    final PrintResult result = await _printer.printBalanceTicket(
      date: date,
      defaults: defaults,
      cardNumber: state.cardNumber,
      expirationDate: state.expirationDate,
      balances: balances,
    );

    if (!mounted) return;
    setState(() {
      _printStatus = result.ok ? PrintStatus.printed : PrintStatus.error;
      _printMessage = result.message;
    });
  }

  ReceiptDefaults? _receiptDefaults() {
    final merchant = context.read<AuthCubit>().merchant;
    if (merchant == null) return null;
    return ReceiptDefaults.forMerchant(
      merchantCode: merchant.code,
      merchantName: merchant.name,
      merchantAddress: merchant.address,
      merchantCity: merchant.city,
      merchantTaxId: merchant.taxId,
      batchNumber: 'ACTUAL',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceCubit>().state;
    final BalanceResult result = state is BalanceCompleted
        ? state.result
        : const BalanceResult(
            status: BalanceStatus.declined,
            balances: [],
            message: 'No se pudo consultar el saldo',
          );
    final bool approved = result.status == BalanceStatus.approved;

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Resultado de la Consulta',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(hideBack: true),
      body: AppSheetPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BalanceStatusContent(
            result: result,
            products: _products,
            printStatus: approved ? _printStatus : PrintStatus.idle,
            printMessage: _printMessage,
            onRetryPrint: approved ? _printTicket : null,
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
    );
  }
}
