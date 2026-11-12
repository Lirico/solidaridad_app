import '../../sales/domain/sale_model.dart';

/// Fila de "Ventas por Producto": cantidad vendida y su equivalente en kg.
class BatchProductItem {
  final String productCode;
  final String label;

  /// Cantidad vendida: unidades (o m³ para `GRANEL`).
  final double quantity;

  /// Equivalente en kg (para `GRANEL`, m³ 1:1 como en el mockup).
  final double kg;

  /// Unidad de [quantity] para mensajes y detalle.
  final String unitLabel;

  const BatchProductItem({
    required this.productCode,
    required this.label,
    required this.quantity,
    required this.kg,
    required this.unitLabel,
  });

  factory BatchProductItem.fromCatalog({
    required String productCode,
    required String label,
    required double quantity,
    required List<ProductInfo> catalog,
  }) {
    ProductInfo? info;
    for (final ProductInfo item in catalog) {
      if (item.code == productCode) {
        info = item;
        break;
      }
    }
    return BatchProductItem(
      productCode: productCode,
      label: label,
      quantity: quantity,
      kg: quantity * (info?.kgPerUnit ?? 1),
      unitLabel: _unitLabel(info?.unit),
    );
  }
}

String _unitLabel(ProductUnit? unit) {
  if (unit == null) return 'unidades';
  if (unit.singular == 'm3') return 'm³';
  return unit.plural;
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

  /// Suma de kg de todas las ventas aprobadas del lote.
  ///
  /// Es la única magnitud agregable hoy: `amount` en la API es **cantidad**
  /// (`api/docs/payments-plan.md`), no importe, así que no hay un total en
  /// pesos hasta que se resuelva la decisión D-3 de `docs/errores-ventas.md`.
  final double totalKg;

  /// Ventas por producto, en orden de catálogo. Solo productos con ventas.
  final List<BatchProductItem> products;

  /// `true` si se alcanzó el tope de páginas y el resumen puede estar incompleto.
  final bool isPartial;

  const BatchSummary({
    required this.batchNumber,
    required this.salesCount,
    required this.totalKg,
    required this.products,
    this.isPartial = false,
  });

  /// Agrupa las ventas aprobadas de la ventana del lote.
  ///
  /// La API ya limita [operations] al lote administrativo actual.
  factory BatchSummary.fromOperations({
    required List<OperationModel> operations,
    required String batchNumber,
    required List<ProductInfo> catalog,
    bool isPartial = false,
  }) {
    final Map<String, BatchProductItem> byProduct =
        <String, BatchProductItem>{};
    int salesCount = 0;

    for (final OperationModel operation in operations) {
      if (operation.result != PaymentResult.approved) continue;

      salesCount++;
      final double quantity =
          (byProduct[operation.productCode]?.quantity ?? 0) + operation.amount;
      byProduct[operation.productCode] = BatchProductItem.fromCatalog(
        productCode: operation.productCode,
        label: operation.productLabel,
        quantity: quantity,
        catalog: catalog,
      );
    }

    final List<String> order = <String>[
      for (final ProductInfo item in catalog) item.code,
    ];
    final List<BatchProductItem> products = byProduct.values.toList()
      ..sort(
        (a, b) => _orderIndex(
          order,
          a.productCode,
        ).compareTo(_orderIndex(order, b.productCode)),
      );

    return BatchSummary(
      batchNumber: batchNumber,
      salesCount: salesCount,
      totalKg: products.fold<double>(0, (sum, item) => sum + item.kg),
      products: products,
      isPartial: isPartial,
    );
  }
}

int _orderIndex(List<String> order, String productCode) {
  final int index = order.indexOf(productCode);
  return index < 0 ? order.length : index;
}
