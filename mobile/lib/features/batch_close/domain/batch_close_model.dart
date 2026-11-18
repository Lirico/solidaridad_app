import '../../sales/domain/sale_model.dart';

/// Fila de "Ventas por Producto" con la unidad publicada por `/products`.
class BatchProductItem {
  final String productCode;
  final String label;

  /// Cantidad vendida: unidades (o m³ para `GRANEL`).
  final double quantity;

  /// Unidad de [quantity] para mensajes y detalle.
  final String unitLabel;

  const BatchProductItem({
    required this.productCode,
    required this.label,
    required this.quantity,
    required this.unitLabel,
  });

  factory BatchProductItem.fromProduct({
    required ProductInfo product,
    required double quantity,
  }) {
    return BatchProductItem(
      productCode: product.code,
      label: product.label,
      quantity: quantity,
      unitLabel: product.unit.labelFor(quantity),
    );
  }
}

/// Resumen del lote actual: lo que la pantalla de Cierre de Lote muestra.
///
/// Se calcula en el cliente a partir del lote actual que entrega
/// `GET /v1/transactions`.
class BatchSummary {
  /// Número de lote mostrado en la pantalla.
  ///
  /// Es una etiqueta de presentación del lote administrativo actual.
  final String batchNumber;

  /// Cantidad de ventas aprobadas del lote.
  final int salesCount;

  /// Ventas por producto, en orden de catálogo. Solo productos con ventas.
  final List<BatchProductItem> products;

  /// `true` si se alcanzó el tope de páginas y el resumen puede estar incompleto.
  final bool isPartial;

  const BatchSummary({
    required this.batchNumber,
    required this.salesCount,
    required this.products,
    this.isPartial = false,
  });

  /// Agrupa las ventas aprobadas de la ventana del lote.
  ///
  /// La API ya limita [operations] al lote administrativo actual.
  factory BatchSummary.fromOperations({
    required List<OperationModel> operations,
    required List<ProductInfo> products,
    required String batchNumber,
    bool isPartial = false,
  }) {
    final Map<String, BatchProductItem> byProduct =
        <String, BatchProductItem>{};
    int salesCount = 0;
    final Map<String, ProductInfo> productsByCode = <String, ProductInfo>{
      for (final product in products) product.code: product,
    };
    final Map<String, int> productOrder = <String, int>{
      for (final entry in products.indexed) entry.$2.code: entry.$1,
    };

    for (final OperationModel operation in operations) {
      if (operation.result != PaymentResult.approved) continue;
      final ProductInfo? product = productsByCode[operation.productCode];
      if (product == null) {
        throw StateError(
          'Producto ${operation.productCode} ausente de /products',
        );
      }

      salesCount++;
      final double quantity =
          (byProduct[operation.productCode]?.quantity ?? 0) + operation.amount;
      byProduct[operation.productCode] = BatchProductItem.fromProduct(
        product: product,
        quantity: quantity,
      );
    }

    final List<BatchProductItem> summaryProducts = byProduct.values.toList()
      ..sort(
        (a, b) => (productOrder[a.productCode] ?? products.length).compareTo(
          productOrder[b.productCode] ?? products.length,
        ),
      );

    return BatchSummary(
      batchNumber: batchNumber,
      salesCount: salesCount,
      products: summaryProducts,
      isPartial: isPartial,
    );
  }
}
