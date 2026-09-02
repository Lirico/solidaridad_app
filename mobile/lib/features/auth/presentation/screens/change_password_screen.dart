import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/brand_logo_image.dart';
import '../widgets/user_menu_button.dart';
import '../widgets/change_password_form_fields.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isFirstLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _isFirstLogin = args['isFirstLogin'] == true;
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthCubit>().changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 68,
        leading: const Center(child: BrandLogoImage(height: 34)),
        titleSpacing: 0,
        title: Text(
          _isFirstLogin ? 'Cambio de Contraseña' : 'Seguridad',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: const [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSessionExpired) {
            context.read<AuthCubit>().logout();
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          } else if (state is AuthSuccess) {
            if (_isFirstLogin) {
              // El backend ya marcó must_change_password=false,
              // navegar directamente al formulario de ventas
              Navigator.pushReplacementNamed(context, AppRoutes.saleForm);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contraseña actualizada correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            }
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message ?? 'Error al cambiar la contraseña',
                ),
                backgroundColor: Colors.red,
              ),
            );
            context.read<AuthCubit>().resetState();
          }
        },

        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isFirstLogin) ...[
                              const SizedBox(height: 10),
                              const Icon(
                                Icons.lock_reset_outlined,
                                size: 44,
                                color: AppColors.primaryOrange,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Bienvenido! Es necesario que cambie su contraseña',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            ChangePasswordFormFields(
                              currentPasswordController:
                                  _currentPasswordController,
                              newPasswordController: _newPasswordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                            ),
                            const SizedBox(height: 32),

                            ElevatedButton(
                              onPressed: state is AuthLoading ? null : _submit,
                              child: state is AuthLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('CONFIRMAR CAMBIO'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
