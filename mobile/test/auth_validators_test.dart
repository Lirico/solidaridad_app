import 'package:flutter_test/flutter_test.dart';
import 'package:solidaridad_app/core/validators/auth_validators.dart';

void main() {
  test('validatePassword exige una minúscula', () {
    expect(
      validatePassword('ABCDEFG1!'),
      'Debe contener al menos una minúscula',
    );
    expect(validatePassword('Abcdefg1!'), isNull);
  });
}
