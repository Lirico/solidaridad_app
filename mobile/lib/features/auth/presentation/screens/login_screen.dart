import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/login_form_fields.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_card.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthCubit>().login(
      usernameOrEmail: _userController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          if (state.mustChangePassword) {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.changePassword,
                              arguments: {'isFirstLogin': true},
                            );
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.saleForm,
                            );
                          }
                        } else if (state is AuthError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.message ?? 'Error de autenticación',
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
                                Icons.lock_open_outlined,
                                size: 44,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(height: AppSpacing.md),
                              const Text(
                                'Ingresar a su Cuenta',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.screenTitle,
                              ),
                              const Divider(height: 40),

                              LoginFormFields(
                                userInputController: _userController,
                                passwordInputController: _passwordController,
                              ),
                              SizedBox(height: AppSpacing.xxl),

                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: state is AuthLoading
                                      ? null
                                      : _handleLogin,
                                  child: state is AuthLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('INGRESAR'),
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
