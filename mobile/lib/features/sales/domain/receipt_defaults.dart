/// Datos del comprobante que la operación todavía no trae.
///
/// Hoy se cargan desde [assets/receipt_defaults.json]. Cuando el backend
/// publique estos campos, se construye el mismo objeto desde la respuesta y
/// el formatter no cambia.
class ReceiptDefaults {
  final String issuerName;
  final String establishmentName;
  final String establishmentAddress;
  final String establishmentCuit;
  final String establishmentCode;
  final String couponNumber;
  final String batchNumber;
  final String authorizationCode;
  final String currency;
  final String installments;
  final String installmentPlan;
  final String originalChargeNumber;

  const ReceiptDefaults({
    required this.issuerName,
    required this.establishmentName,
    required this.establishmentAddress,
    required this.establishmentCuit,
    required this.establishmentCode,
    required this.couponNumber,
    required this.batchNumber,
    required this.authorizationCode,
    required this.currency,
    required this.installments,
    required this.installmentPlan,
    required this.originalChargeNumber,
  });

  factory ReceiptDefaults.fromJson(Map<String, dynamic> json) {
    return ReceiptDefaults(
      issuerName: _string(json, 'issuer_name'),
      establishmentName: _string(json, 'establishment_name'),
      establishmentAddress: _string(json, 'establishment_address'),
      establishmentCuit: _string(json, 'establishment_cuit'),
      establishmentCode: _string(json, 'establishment_code'),
      couponNumber: _string(json, 'coupon_number'),
      batchNumber: _string(json, 'batch_number'),
      authorizationCode: _string(json, 'authorization_code'),
      currency: _string(json, 'currency'),
      installments: _string(json, 'installments'),
      installmentPlan: _string(json, 'installment_plan'),
      originalChargeNumber: _string(json, 'original_charge_number'),
    );
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('receipt_defaults.$key debe ser un texto');
    }
    return value;
  }
}
