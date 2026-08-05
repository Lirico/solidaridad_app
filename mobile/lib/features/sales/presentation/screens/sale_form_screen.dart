import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale_model.dart';
import '../cubit/sales_cubit.dart';

import '../widgets/amount_input_formatter.dart';
import '../widgets/product_selector.dart';
import '../widgets/card_fields_container.dart';
import '../widgets/sale_form_header.dart';

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedProductCode = 'GARRAFA_10';
  String _selectedProductLabel = 'Garrafa 10 kg';
  List<ProductInfo> _products = [];
  bool _loadingProducts = true;

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _unitsController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final authState = context.read<AuthCubit>().state;
    final token = authState is AuthSuccess ? authState.user!.token : '';
    final repo = context.read<SalesCubit>().salesRepository;
    try {
      final products = await repo.fetchProducts(token: token);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
        if (products.isNotEmpty) {
          _selectedProductCode = products.first.code;
          _selectedProductLabel = products.first.label;
        }
      });
    } on SessionExpiredException {
      if (!mounted) return;
      context.read<AuthCubit>().logout();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _unitsController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SaleFormHeader(),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.assignment_outlined,
                                  color: Colors.grey,
                                ),
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

                            if (_loadingProducts)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
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
                            const Text(
                              'Cantidad de Unidades',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _unitsController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [AmountInputFormatter()],
                              decoration: const InputDecoration(
                                hintText: 'Ingresar Unidades',
                                prefixIcon: Icon(Icons.propane_tank_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La cantidad es obligatoria';
                                }
                                final normalized = value.replaceAll(',', '.');
                                final parsedUnits = double.tryParse(normalized);
                                if (parsedUnits == null) {
                                  return 'Ingrese un número válido';
                                }
                                if (parsedUnits <= 0) {
                                  return 'La cantidad debe ser mayor a cero';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            CardFieldsContainer(
                              cardNumberController: _cardNumberController,
                              expiryController: _expiryController,
                              cvvController: _cvvController,
                              cardHolderController: _cardHolderController,
                            ),

                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  final cubit = context.read<SalesCubit>();
                                  final units =
                                      double.tryParse(
                                        _unitsController.text.replaceAll(
                                          ',',
                                          '.',
                                        ),
                                      ) ??
                                      0;

                                  cubit.showReview(
                                    productCode: _selectedProductCode,
                                    productLabel: _selectedProductLabel,
                                    amount: units,
                                    cardNumber: _cardNumberController.text,
                                    cardHolder: _cardHolderController.text,
                                    cvv: _cvvController.text,
                                    expirationDate: _expiryController.text
                                        .replaceAll('/', ''),
                                  );

                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.saleReview,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'CONTINUAR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
