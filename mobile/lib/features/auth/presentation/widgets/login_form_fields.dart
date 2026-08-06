import 'package:flutter/material.dart';
import '../../../../core/validators/auth_validators.dart';
import '../../../../core/theme/app_text_styles.dart';

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
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usuario o Correo',
          style: AppTextStyles.formLabel.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.userInputController,
          style: const TextStyle(fontSize: 22),
          keyboardType: TextInputType.emailAddress,
          validator: validateUsernameOrEmail,
          decoration: const InputDecoration(
            hintText: 'ejemplo@gas.com',
            prefixIcon: Icon(Icons.person_outline, size: 24),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Contraseña',
          style: AppTextStyles.formLabel.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.passwordInputController,
          style: const TextStyle(fontSize: 22),
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Ingrese su contraseña',
            prefixIcon: const Icon(Icons.lock_outline, size: 24),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 24,
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
