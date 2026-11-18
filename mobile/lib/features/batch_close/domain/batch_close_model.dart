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

  /// Catálogo vigente usado para validar y ordenar el resumen y su ticket.
  final List<ProductInfo> catalog;

  /// `true` si se alcanzó el tope de páginas y el resumen puede estar incompleto.
  final bool isPartial;

  const BatchSummary({
    required this.batchNumber,
    required this.salesCount,
    required this.products,
    this.catalog = const <ProductInfo>[],
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
      catalog: List<ProductInfo>.unmodifiable(products),
      isPartial: isPartial,
    );
  }
}

/// Un producto del ticket de cierre: ventas y anulaciones de ese corte.
class BatchCloseProductSlip {
  final ProductInfo product;
  final int salesCount;
  final double salesQuantity;
  final int voidCount;
  final double voidQuantity;

  const BatchCloseProductSlip({
    required this.product,
    required this.salesCount,
    required this.salesQuantity,
    required this.voidCount,
    required this.voidQuantity,
  });

  String get code => product.code;

  String get label => product.label;

  int get totalCount => salesCount - voidCount;

  double get totalQuantity => salesQuantity - voidQuantity;

  String unitLabel(double quantity) => product.unit.labelFor(quantity);
}

/// Comprobante de un corte ya cerrado, agrupado por producto.
///
/// Las notas de crédito no existen en la API: esa línea queda en cero.
/// Cada cantidad conserva la unidad publicada por `/products`; no suma
/// magnitudes heterogéneas entre productos.
class BatchCloseTicket {
  final List<BatchCloseProductSlip> products;

  const BatchCloseTicket({required this.products});

  int get salesCount =>
      products.fold<int>(0, (sum, item) => sum + item.salesCount);

  int get voidCount =>
      products.fold<int>(0, (sum, item) => sum + item.voidCount);

  int get totalCount => salesCount - voidCount;

  factory BatchCloseTicket.fromOperations({
    required List<OperationModel> operations,
    required List<ProductInfo> products,
  }) {
    final Map<String, _ProductTally> byProduct = <String, _ProductTally>{};
    final productsByCode = <String, ProductInfo>{
      for (final product in products) product.code: product,
    };
    final productOrder = <String, int>{
      for (final entry in products.indexed) entry.$2.code: entry.$1,
    };

    for (final OperationModel operation in operations) {
      final bool approved = operation.result == PaymentResult.approved;
      final bool voided = operation.result == PaymentResult.voided;
      if (!approved && !voided) continue;

      final product = productsByCode[operation.productCode];
      if (product == null) {
        throw StateError(
          'Producto ${operation.productCode} ausente de /products',
        );
      }
      final _ProductTally tally = byProduct.putIfAbsent(
        operation.productCode,
        () => _ProductTally(product),
      );
      // La API representa una anulación actualizando la venta original a
      // VOIDED, no agregando una segunda operación. Por eso una anulada forma
      // parte de las ventas brutas y, además, resta en ANULACIONES.
      tally.salesCount += 1;
      tally.salesQuantity += operation.amount;
      if (voided) {
        tally.voidCount += 1;
        tally.voidQuantity += operation.amount;
      }
    }

    final List<BatchCloseProductSlip> ticketProducts =
        byProduct.entries
            .map(
              (entry) => BatchCloseProductSlip(
                product: entry.value.product,
                salesCount: entry.value.salesCount,
                salesQuantity: entry.value.salesQuantity,
                voidCount: entry.value.voidCount,
                voidQuantity: entry.value.voidQuantity,
              ),
            )
            .toList()
          ..sort(
            (a, b) => (productOrder[a.code] ?? products.length).compareTo(
              productOrder[b.code] ?? products.length,
            ),
          );

    return BatchCloseTicket(products: ticketProducts);
  }
}

class _ProductTally {
  final ProductInfo product;
  int salesCount = 0;
  double salesQuantity = 0;
  int voidCount = 0;
  double voidQuantity = 0;

  _ProductTally(this.product);
}
