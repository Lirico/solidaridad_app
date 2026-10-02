enum PaymentResult { approved, declined, connectionError, voided }

/// Estado de la impresión del ticket en la pantalla de resultado.
enum PrintStatus { idle, printing, printed, error }

class OperationModel {
  final String id;
  final String productCode;
  final String productLabel;
  final double amount;
  final String cardNumber;
  final PaymentResult result;
  final DateTime date;
  final String? userMessage;

  const OperationModel({
    required this.id,
    required this.productCode,
    required this.productLabel,
    required this.amount,
    required this.cardNumber,
    required this.result,
    required this.date,
    this.userMessage,
  });

  factory OperationModel.fromJson(Map<String, dynamic> json) {
    final code = json['product'] as String? ?? '';
    return OperationModel(
      id: json['transaction_number'] as String? ?? '',
      productCode: code,
      productLabel: _labelForProductCode(code),
      amount: double.tryParse(json['amount'] as String? ?? '0') ?? 0.0,
      cardNumber: '•••• ${json['card_last4'] as String? ?? '0000'}',
      result: _parseStatus(json['status'] as String? ?? ''),
      date:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),

      userMessage: json['user_message'] as String?,
    );
  }

  static String _labelForProductCode(String code) {
    switch (code) {
      case 'GARRAFA_10':
        return 'Garrafa 10 kg';
      case 'GARRAFA_15':
        return 'Garrafa 15 kg';
      case 'GARRAFA_30':
        return 'Garrafa 30 kg';
      case 'TUBO_45':
        return 'Tubo 45 kg';
      case 'GRANEL':
        return 'Granel';
      default:
        return code;
    }
  }

  static PaymentResult _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return PaymentResult.approved;
      case 'DECLINED':
        return PaymentResult.declined;
      case 'VOIDED':
        return PaymentResult.voided;
      case 'FAILED':
      case 'UNKNOWN':
      case 'PENDING':
      default:
        return PaymentResult.connectionError;
    }
  }
}

/// Resultado de una anulación. Reemplaza el mock en el Paso 5 con la respuesta
/// real del repositorio.
class VoidResult {
  final bool isVoided;
  final bool isDeclined;
  final bool isUnknown;
  final bool connectionError;
  final bool sessionExpired;
  final String message;

  const VoidResult({
    required this.isVoided,
    required this.isDeclined,
    required this.isUnknown,
    required this.connectionError,
    required this.sessionExpired,
    required this.message,
  });

  const VoidResult.voided({this.message = 'Anulación aprobada'})
    : isVoided = true,
      isDeclined = false,
      isUnknown = false,
      connectionError = false,
      sessionExpired = false;

  const VoidResult.declined({this.message = 'Anulación rechazada'})
    : isVoided = false,
      isDeclined = true,
      isUnknown = false,
      connectionError = false,
      sessionExpired = false;

  const VoidResult.unknown({this.message = 'No pudimos confirmar la anulación'})
    : isVoided = false,
      isDeclined = false,
      isUnknown = true,
      connectionError = false,
      sessionExpired = false;

  const VoidResult.connectionFailure({
    this.message = 'No se pudo anular. Intente nuevamente.',
  }) : isVoided = false,
       isDeclined = false,
       isUnknown = false,
       connectionError = true,
       sessionExpired = false;

  const VoidResult.sessionExpiredResult()
    : isVoided = false,
      isDeclined = false,
      isUnknown = false,
      connectionError = false,
      sessionExpired = true,
      message = 'Su sesión ha expirado. Vuelva a iniciar sesión.';
}

class SaleResponse {
  final bool isApproved;
  final String operationNumber;
  final String message;
  final String errorCode;
  final bool connectionError;
  final bool sessionExpired;

  const SaleResponse({
    required this.isApproved,
    required this.operationNumber,
    required this.message,
    required this.errorCode,
    this.connectionError = false,
    this.sessionExpired = false,
  });
}

class ProductUnit {
  final String singular;
  final String plural;

  const ProductUnit({required this.singular, required this.plural});

  bool get allowsDecimals => singular == 'm3';

  static const unidades = ProductUnit(singular: 'unidad', plural: 'unidades');
  static const metrosCubicos = ProductUnit(singular: 'm3', plural: 'm3');

  static ProductUnit forProductCode(String code) {
    return code == 'GRANEL' ? metrosCubicos : unidades;
  }
}

class ProductInfo {
  final String code;
  final String label;
  final ProductUnit unit;

  const ProductInfo({
    required this.code,
    required this.label,
    this.unit = ProductUnit.unidades,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final rawUnit = json['unit'];
    final ProductUnit unit;
    if (rawUnit is Map) {
      unit = ProductUnit(
        singular: rawUnit['singular'] as String? ?? 'unidad',
        plural: rawUnit['plural'] as String? ?? 'unidades',
      );
    } else {
      unit = ProductUnit.forProductCode(code);
    }
    return ProductInfo(
      code: code,
      label: json['label'] as String,
      unit: unit,
    );
  }
}

/// Valida la cantidad del formulario.
///
/// Garrafas y tubos exigen un entero. El granel (m³) admite hasta 2 decimales,
/// que es la escala que acepta la API.
String? validateSaleQuantity(String? value, {required bool allowsDecimals}) {
  if (value == null || value.trim().isEmpty) {
    return 'La cantidad es obligatoria';
  }
  final normalized = value.trim().replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null) {
    return 'Ingrese un número válido';
  }
  if (parsed <= 0) {
    return 'La cantidad debe ser mayor a cero';
  }
  final dot = normalized.indexOf('.');
  final decimals = dot < 0 ? '' : normalized.substring(dot + 1);
  if (decimals.length > 2) {
    return 'La cantidad admite como máximo 2 decimales';
  }
  if (!allowsDecimals && parsed != parsed.truncateToDouble()) {
    return 'La cantidad debe ser un número entero';
  }
  return null;
}
