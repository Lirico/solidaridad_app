import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/widgets/load_error_notice.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../data/product_catalog_store.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale_model.dart';
import '../cubit/sales_cubit.dart';

import '../widgets/amount_input_formatter.dart';
import '../widgets/product_selector.dart';

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProductCatalogStore _productCatalogStore;

  String _selectedProductCode = '';
  String _selectedProductLabel = '';
  List<ProductInfo> _products = [];
  bool _loadingProducts = true;
  String? _productsError;

  final _unitsController = TextEditingController();

  ProductInfo? get _selectedProduct {
    for (final product in _products) {
      if (product.code == _selectedProductCode) return product;
    }
    return null;
  }

  String get _quantityUnit => _selectedProduct?.unit.plural ?? '';

  bool get _canContinue =>
      !_loadingProducts && _productsError == null && _products.isNotEmpty;

  bool get _allowsDecimals => _selectedProduct?.unit.allowsDecimals ?? false;

  @override
  void initState() {
    super.initState();
    _productCatalogStore = context.read<ProductCatalogStore>();
    _productCatalogStore.addListener(_onCatalogUpdated);
    _loadProducts();
  }

  void _onCatalogUpdated() {
    final products = _productCatalogStore.current;
    if (!mounted || products == null) return;
    setState(() => _replaceProducts(products));
  }

  void _replaceProducts(List<ProductInfo> products) {
    _products = products;
    _loadingProducts = false;
    _productsError = null;
    if (products.isEmpty) {
      _selectedProductCode = '';
      _selectedProductLabel = '';
      return;
    }

    ProductInfo? selected;
    for (final product in products) {
      if (product.code == _selectedProductCode) {
        selected = product;
        break;
      }
    }
    selected ??= products.first;
    _selectedProductCode = selected.code;
    _selectedProductLabel = selected.label;
  }

  Future<void> _loadProducts() async {
    final authState = context.read<AuthCubit>().state;
    final token = authState is AuthSuccess ? authState.user!.token : '';
    if (_productsError != null || !_loadingProducts) {
      setState(() {
        _loadingProducts = true;
        _productsError = null;
      });
    }
    try {
      final products = await _productCatalogStore.getOrLoad(token: token);
      if (!mounted) return;
      setState(() => _replaceProducts(products));
    } on SessionExpiredException {
      if (!mounted) return;
      context.read<AuthCubit>().logout();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } on DataLoadException catch (error) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _loadingProducts = false;
        _productsError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _loadingProducts = false;
        _productsError = 'Ocurrió un error inesperado. Reintente.';
      });
    }
  }

  @override
  void dispose() {
    _productCatalogStore.removeListener(_onCatalogUpdated);
    _unitsController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      final units =
          double.tryParse(_unitsController.text.replaceAll(',', '.')) ?? 0;

      context.read<SalesCubit>().setProductAndAmount(
        productCode: _selectedProductCode,
        productLabel: _selectedProductLabel,
        amount: units,
      );

      Navigator.pushNamed(context, AppRoutes.saleSelectNewOperation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Nueva Operación',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.assignment_outlined, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Iniciar Nueva Venta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                const SizedBox(height: 8),

                if (_loadingProducts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_productsError != null)
                  LoadErrorNotice(
                    message: _productsError!,
                    onRetry: _loadProducts,
                  )
                else if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No hay productos disponibles.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                else ...[
                  ProductSelector(
                    products: _products,
                    selectedCode: _selectedProductCode,
                    onProductChanged: (code) {
                      final product = _products.firstWhere(
                        (p) => p.code == code,
                      );
                      setState(() {
                        _selectedProductCode = code;
                        _selectedProductLabel = product.label;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cantidad ($_quantityUnit)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _unitsController,
                    style: const TextStyle(fontSize: 22),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [AmountInputFormatter()],
                    decoration: InputDecoration(
                      hintText: 'Ingresar $_quantityUnit',
                      prefixIcon: const Icon(
                        Icons.propane_tank_outlined,
                        size: 24,
                      ),
                    ),
                    validator: (value) => validateSaleQuantity(
                      value,
                      allowsDecimals: _allowsDecimals,
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.xxl),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: !_canContinue ? null : _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text(
                      'SIGUIENTE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
