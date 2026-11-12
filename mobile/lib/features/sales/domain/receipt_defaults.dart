import 'sale_model.dart';

/// Datos del comprobante que no viajan en la operación.
///
/// El comercio sale de la cuenta. El cupón y la autorización salen de
/// [OperationModel]. El emisor, la moneda y el plan son fijos de este flujo.
class ReceiptDefaults {
  static const String issuer = 'Solidaridad';
  static const String currencyCode = 'ARS';
  static const String installmentCount = '1';
  static const String planName = 'Contado';

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

  /// Arma el comprobante de [operation] con el comercio vigente de la cuenta.
  ///
  /// La ciudad se agrega a la dirección, en la misma línea. Sin `receipt`,
  /// el cupón y la autorización quedan vacíos.
  factory ReceiptDefaults.forSale({
    required String merchantCode,
    required String merchantName,
    required String merchantAddress,
    required String merchantCity,
    required String merchantTaxId,
    required OperationModel operation,
  }) {
    return ReceiptDefaults(
      issuerName: issuer,
      establishmentName: merchantName,
      establishmentAddress: printedAddress(merchantAddress, merchantCity),
      establishmentCuit: merchantTaxId,
      establishmentCode: merchantCode,
      couponNumber: operation.couponNumber ?? '',
      batchNumber: '',
      authorizationCode: operation.authorizationCode ?? '',
      currency: currencyCode,
      installments: installmentCount,
      installmentPlan: planName,
      originalChargeNumber: '',
    );
  }

  /// Comercio de la cuenta, sin cupón ni autorización.
  factory ReceiptDefaults.forMerchant({
    required String merchantCode,
    required String merchantName,
    required String merchantAddress,
    required String merchantCity,
    required String merchantTaxId,
  }) {
    return ReceiptDefaults.forSale(
      merchantCode: merchantCode,
      merchantName: merchantName,
      merchantAddress: merchantAddress,
      merchantCity: merchantCity,
      merchantTaxId: merchantTaxId,
      operation: OperationModel(
        id: '',
        productCode: '',
        productLabel: '',
        amount: 0,
        cardNumber: '',
        result: PaymentResult.approved,
        date: DateTime.utc(2026),
      ),
    );
  }

  static String printedAddress(String address, String city) {
    final street = address.trim();
    final locality = city.trim();
    if (street.isEmpty) return locality;
    if (locality.isEmpty) return street;
    return '$street, $locality';
  }
}
