import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/features/sales/presentation/widgets/amount_input_formatter.dart';

void main() {
  final formatter = AmountInputFormatter();

  TextEditingValue apply(String previous, String next) {
    return formatter.formatEditUpdate(
      TextEditingValue(text: previous),
      TextEditingValue(text: next),
    );
  }

  test('acepta el máximo de DE4', () {
    expect(apply('', '9999999999,99').text, '9999999999,99');
  });

  test('rechaza un dígito entero de más', () {
    expect(apply('9999999999', '99999999999').text, '9999999999');
  });

  test('rechaza un tercer decimal', () {
    expect(apply('1,99', '1,999').text, '1,99');
  });
}
