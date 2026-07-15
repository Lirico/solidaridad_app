import 'package:flutter/services.dart';

class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Obtener el texto limpio
    String text = newValue.text;

    // Permitir campo vacío
    if (text.isEmpty) {
      return newValue;
    }

    // Eliminar cualquier punto (separador de miles no permitido)
    text = text.replaceAll('.', '');

    // Contar comas y permitir solo una
    final commaCount = ','.allMatches(text).length;
    if (commaCount > 1) {
      return oldValue;
    }

    // Filtrar caracteres: solo dígitos y coma
    final filtered = StringBuffer();
    bool hasComma = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ',') {
        if (!hasComma) {
          filtered.write(char);
          hasComma = true;
        }
      } else if (char == '-' && i == 0) {
        // Permitir signo negativo solo al inicio (aunque no se usa en este caso)
        filtered.write(char);
      } else if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        // Dígito 0-9
        filtered.write(char);
      }
    }

    text = filtered.toString();

    // Si comienza con coma, anteponer "0"
    if (text.startsWith(',')) {
      text = '0$text';
    }

    // Si solo tiene un "-" vacío, permitirlo
    if (text == '-') {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // Recalcular la posición del cursor
    final cursorPosition = text.length;

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
