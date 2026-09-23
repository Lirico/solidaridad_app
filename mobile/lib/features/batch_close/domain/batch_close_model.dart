import '../../sales/domain/sale_model.dart';

/// Equivalencia en kg por unidad vendida.
///
/// El catálogo (`packages/catalog`) expone código, etiqueta y unidad
/// (`unidades` / `m3`) pero **no** el peso por producto. Este mapa replica la
/// equivalencia que usa el mockup del cliente (15 garrafas de 10 kg = 150 Kg).
/// `GRANEL` se mide en m³ y el mockup lo muestra en Kg, así que vale 1:1.
/// **Pendiente:** cuando se confirme el endpoint del backend que expone el peso
/// por producto, este mapa se reemplaza por el valor del catálogo. Ver
/// `docs/gaps.md` (G-P2-10).
const Map<String, double> batchKgPerUnit = <String, double>{
  'GARRAFA_10': 10,
  'GARRAFA_15': 15,
  'GARRAFA_30': 30,
  'TUBO_45': 45,
  'GRANEL': 1,
};

/// Orden de las filas de "Ventas por Producto" (mismo orden del catálogo).
const List<String> _productOrder = <String>[
  'GARRAFA_10',
  'GARRAFA_15',
  'GARRAFA_30',
  'TUBO_45',
  'GRANEL',
];

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

  factory BatchProductItem.fromCode({
    required String productCode,
    required String label,
    required double quantity,
  }) {
    return BatchProductItem(
      productCode: productCode,
      label: label,
      quantity: quantity,
      kg: quantity * (batchKgPerUnit[productCode] ?? 1),
      unitLabel: productCode == 'GRANEL' ? 'm³' : 'unidades',
    );
  }
}

/// Resumen del lote actual: lo que la pantalla de Cierre de Lote muestra.
///
/// Se calcula en el cliente a partir de `GET /v1/transactions` porque hoy la API
/// no expone un concepto de lote/cierre (ver `docs/gaps.md`, G-P2-10).
class BatchSummary {
  /// Número de lote mostrado en la pantalla.
  ///
  /// **Provisorio:** lo aporta la app mientras la API no exponga el lote real
  /// (ver `docs/gaps.md`, G-P2-10).
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
  /// Ventana = desde el inicio del día local ([now]): mientras no exista el
  /// contrato de cierre no hay otro corte posible (ver `docs/gaps.md`,
  /// G-P2-10).
  factory BatchSummary.fromOperations({
    required List<OperationModel> operations,
    required String batchNumber,
    DateTime? now,
    bool isPartial = false,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime cutoff = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );

    final Map<String, BatchProductItem> byProduct =
        <String, BatchProductItem>{};
    int salesCount = 0;

    for (final OperationModel operation in operations) {
      if (operation.result != PaymentResult.approved) continue;
      if (!operation.date.isAfter(cutoff)) continue;

      salesCount++;
      final double quantity =
          (byProduct[operation.productCode]?.quantity ?? 0) + operation.amount;
      byProduct[operation.productCode] = BatchProductItem.fromCode(
        productCode: operation.productCode,
        label: operation.productLabel,
        quantity: quantity,
      );
    }

    final List<BatchProductItem> products = byProduct.values.toList()
      ..sort(
        (a, b) =>
            _orderIndex(a.productCode).compareTo(_orderIndex(b.productCode)),
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

int _orderIndex(String productCode) {
  final int index = _productOrder.indexOf(productCode);
  return index < 0 ? _productOrder.length : index;
}
