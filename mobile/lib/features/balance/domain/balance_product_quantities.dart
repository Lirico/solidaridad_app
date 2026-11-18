import '../../sales/domain/sale_model.dart';
import 'balance_model.dart';

/// Combina las cantidades del saldo con etiqueta y unidad de `GET /products`.
///
/// No convierte magnitudes: garrafas y tubos permanecen en unidades y granel
/// permanece en m3. Un código ausente del catálogo invalida el comprobante.
List<ProductQuantity> balanceProductQuantities(
  List<BalanceItem> items,
  List<ProductInfo> products,
) {
  final byCode = <String, ProductInfo>{
    for (final product in products) product.code: product,
  };
  return items.map((item) {
    final product = byCode[item.product];
    if (product == null) {
      throw StateError('Producto ${item.product} ausente de /products');
    }
    return ProductQuantity(product: product, quantity: item.availableBalance);
  }).toList();
}
