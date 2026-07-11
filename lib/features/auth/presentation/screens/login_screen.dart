import 'package:flutter/material.dart';
import '../widgets/login_form_fields.dart';
import '../widgets/auth_header.dart'; // 👑 NUEVO IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const AuthHeader(), // 👑 REUTILIZADO: Limpiamos por completo la visual superior
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          const Icon(
                            Icons.lock_open_outlined,
                            size: 44,
                            color: Color(0xFF1A4F9C),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ingresar a su Cuenta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Divider(height: 40),

                          LoginFormFields(
                            userInputController: _userController,
                            passwordInputController: _passwordController,
                          ),
                          const SizedBox(height: 40),

                          ElevatedButton(
                            onPressed: () {
                              // Simulación temporal de navegación para que pruebes el flujo completo
                              print('Usuario: ${_userController.text}');
                              print('Clave: ${_passwordController.text}');
                              Navigator.pushReplacementNamed(
                                context,
                                '/sales_form',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A4F9C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
