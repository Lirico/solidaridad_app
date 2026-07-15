import 'package:flutter/material.dart';
import '../../../../core/validators/auth_validators.dart';
import '../../../../core/theme/app_text_styles.dart';

class RegisterFormFields extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  const RegisterFormFields({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  @override
  State<RegisterFormFields> createState() => _RegisterFormFieldsState();
}

class _RegisterFormFieldsState extends State<RegisterFormFields> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input de Nombre Completo
        const Text('Nombre Completo', style: AppTextStyles.formLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.nameController,
          textCapitalization: TextCapitalization.words,
          validator: validateName,
          decoration: const InputDecoration(
            hintText: 'Ingrese su nombre',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 20),

        // Input de Correo Electrónico
        const Text('Correo Electrónico', style: AppTextStyles.formLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.emailController,
          keyboardType: TextInputType.emailAddress,
          validator: validateEmail,
          decoration: const InputDecoration(
            hintText: 'ejemplo@correo.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),

        // Input de Contraseña
        const Text('Contraseña', style: AppTextStyles.formLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.passwordController,
          obscureText: _obscurePassword,
          validator: validatePassword,
          decoration: InputDecoration(
            hintText: 'Cree una contraseña',
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
        const SizedBox(height: 20),

        // Input de Confirmar Contraseña
        const Text('Confirmar Contraseña', style: AppTextStyles.formLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          validator: (value) =>
              validateConfirmPassword(value, widget.passwordController.text),
          decoration: InputDecoration(
            hintText: 'Repita la contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
