import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../widgets/register_form_fields.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_card.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthCubit>().register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: const AppBottomNavBar(enabled: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const AuthHeader(),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AuthCard(
                    child: BlocConsumer<AuthCubit, AuthState>(
                      listener: (context, state) {
                        if (state is AuthSuccess) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          );
                        } else if (state is AuthError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.message ?? 'Error al registrarse',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          context.read<AuthCubit>().resetState();
                        }
                      },
                      builder: (context, state) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: AppSpacing.sm),
                              Icon(
                                Icons.person_add_outlined,
                                size: 44,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(height: AppSpacing.md),
                              const Text(
                                'Crear una Cuenta',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.screenTitle,
                              ),
                              const Divider(height: 40),

                              RegisterFormFields(
                                nameController: _nameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                              ),
                              SizedBox(height: AppSpacing.xxl),

                              ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : _handleRegister,
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('REGISTRARSE'),
                              ),
                              SizedBox(height: AppSpacing.md),

                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.login,
                                  );
                                },
                                child: const Text(
                                  '¿Ya tiene una cuenta? Iniciar sesión',
                                  style: AppTextStyles.linkButton,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
