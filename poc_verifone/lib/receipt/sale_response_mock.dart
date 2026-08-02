import 'package:poc_verifone/psdk/psdk_msr_mock.dart';
import 'package:poc_verifone/receipt/receipt_data.dart';

/// Fake `POST /v1/transactions` (+ list fields) for ticket POC.
class SaleResponseMock {
  SaleResponseMock._();

  /// Approved sale using the lab card from [PsdkMsrMock].
  static Map<String, dynamic> approvedGarrafa10({
    String? transactionNumber,
    DateTime? createdAt,
  }) {
    final pan = PsdkMsrMock.pan;
    final at = createdAt ?? DateTime.now();
    return {
      'transaction_number':
          transactionNumber ?? 'TXN-MOCK-${at.millisecondsSinceEpoch}',
      'status': 'APPROVED',
      'user_message': 'Transacción aprobada',
      'created_at': at.toUtc().toIso8601String(),
      // list/detail extras (TransactionItemResponse)
      'product': 'GARRAFA_10',
      'amount': '150.00',
      'card_last4': pan.length >= 4 ? pan.substring(pan.length - 4) : pan,
    };
  }

  static ReceiptData toReceipt(Map<String, dynamic> json) {
    return ReceiptData.fromTransactionJson(
      json,
      cardHolder: PsdkMsrMock.name,
    );
  }
}
