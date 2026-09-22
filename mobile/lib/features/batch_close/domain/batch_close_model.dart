// Modelos de vista de la pantalla de Cierre de Lote.
//
// Prototipo visual: son solo estructuras de datos para dibujar la pantalla. El
// cálculo del resumen real (ventas de la terminal, kilos por producto, ventana
// del lote) llega con la integración pendiente de contrato: ver `docs/gaps.md`
// (G-P2-10).

/// Fila de "Ventas por Producto": cantidad vendida y su equivalente en kg.
class BatchProductItem {
  final String productCode;
  final String label;

  /// Cantidad vendida: unidades (o m³ para `GRANEL`).
  final double quantity;

  /// Equivalente en kg.
  final double kg;

  /// Unidad de [quantity], para mensajes y detalle.
  final String unitLabel;

  const BatchProductItem({
    required this.productCode,
    required this.label,
    required this.quantity,
    required this.kg,
    required this.unitLabel,
  });
}

/// Resumen del lote que muestra la pantalla.
class BatchSummary {
  /// Número de lote mostrado en la pantalla (ej. `000123`).
  final String batchNumber;

  /// Cantidad de ventas del lote.
  final int salesCount;

  /// Total del lote expresado en kg.
  final double totalKg;

  /// Ventas por producto, en orden de catálogo.
  final List<BatchProductItem> products;

  /// `true` si el resumen puede estar incompleto.
  final bool isPartial;

  const BatchSummary({
    required this.batchNumber,
    required this.salesCount,
    required this.totalKg,
    required this.products,
    this.isPartial = false,
  });
}
