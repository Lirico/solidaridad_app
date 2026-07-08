import 'package:flutter/material.dart';

class LoginFormFields extends StatefulWidget {
  final TextEditingController userInputController;
  final TextEditingController passwordInputController;

  const LoginFormFields({
    super.key,
    required this.userInputController,
    required this.passwordInputController,
  });

  @override
  State<LoginFormFields> createState() => _LoginFormFieldsState();
}

class _LoginFormFieldsState extends State<LoginFormFields> {
  bool _obscurePassword = true; // Estado local para ocultar/mostrar contraseña

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input de Usuario
        const Text(
          'Usuario o Correo',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.userInputController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'ejemplo@gas.com',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 20),

        // Input de Contraseña
        const Text(
          'Contraseña',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.passwordInputController,
          obscureText: _obscurePassword, // Oculta el texto dinámicamente
          decoration: InputDecoration(
            hintText: 'Ingrese su contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
