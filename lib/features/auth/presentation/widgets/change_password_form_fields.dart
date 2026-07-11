import 'package:flutter/material.dart';

class ChangePasswordFormFields extends StatelessWidget {
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;

  const ChangePasswordFormFields({
    super.key,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Icon(Icons.lock_outline, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Actualizar Contraseña',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const Divider(height: 32),

        TextFormField(
          controller: currentPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña Actual',
            prefixIcon: Icon(Icons.lock_open_outlined),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Campo requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        TextFormField(
          controller: newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nueva Contraseña',
            prefixIcon: Icon(Icons.vpn_key_outlined),
            hintText: 'Mínimo 6 caracteres',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Campo requerido';
            }
            if (value.length < 6) {
              return 'Debe tener al menos 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        TextFormField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmar Nueva Contraseña',
            prefixIcon: Icon(Icons.check_circle_outline),
          ),
          validator: (value) {
            if (value != newPasswordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
      ],
    );
  }
}
