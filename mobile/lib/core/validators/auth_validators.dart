String? validateRequired(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName es obligatorio';
  }
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'El correo electrónico es obligatorio';
  }
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Ingrese un correo electrónico válido';
  }
  return null;
}

String? validateUsernameOrEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'El usuario o correo es obligatorio';
  }
  return null;
}

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'El nombre es obligatorio';
  }
  if (value.trim().length < 3) {
    return 'El nombre debe tener al menos 3 caracteres';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'La contraseña es obligatoria';
  }
  if (value.length < 8 || value.length > 20) {
    return 'La contraseña debe tener entre 8 y 20 caracteres';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return 'Debe contener al menos una mayúscula';
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return 'Debe contener al menos un número';
  }
  if (!value.contains(RegExp(r'[^a-zA-Z0-9\s]'))) {
    return 'Debe contener al menos un caracter especial (ej: .)';
  }
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Debe confirmar la contraseña';
  }
  if (value != password) {
    return 'Las contraseñas no coinciden';
  }
  return null;
}
