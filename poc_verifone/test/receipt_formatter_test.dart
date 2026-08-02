import 'package:flutter_test/flutter_test.dart';
import 'package:poc_verifone/receipt/receipt_formatter.dart';
import 'package:poc_verifone/receipt/sale_response_mock.dart';

void main() {
  test('SaleResponseMock builds receipt with last4 and approved label', () {
    final json = SaleResponseMock.approvedGarrafa10(
      transactionNumber: 'TXN-1',
      createdAt: DateTime.utc(2026, 8, 2, 15, 30, 0),
    );
    final receipt = SaleResponseMock.toReceipt(json);

    expect(receipt.isApproved, isTrue);
    expect(receipt.statusLabel, 'APROBADA');
    expect(receipt.cardLast4, '7403');
    expect(receipt.maskedPan, '•••• 7403');
    expect(receipt.productLabel, 'Garrafa 10 kg');

    final plain = ReceiptFormatter.toPlainText(receipt);
    expect(plain, contains('APROBADA'));
    expect(plain, contains('TXN-1'));
    expect(plain, contains('•••• 7403'));
    expect(plain, contains('150.00'));

    final html = ReceiptFormatter.toHtml(receipt);
    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('APROBADA'));
    expect(html, contains('Garrafa 10 kg'));
    expect(html, isNot(contains('6063001014007403')));
  });
}
