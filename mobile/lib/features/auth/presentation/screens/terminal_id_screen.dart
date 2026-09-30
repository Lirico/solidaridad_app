import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/terminal/terminal_id_store.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';

class TerminalIdScreen extends StatefulWidget {
  const TerminalIdScreen({super.key});

  @override
  State<TerminalIdScreen> createState() => _TerminalIdScreenState();
}

class _TerminalIdScreenState extends State<TerminalIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await context.read<TerminalIdStore>().read();
    if (!mounted) return;
    final initial = stored ?? labInstallationId;
    _controller.text = initial;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final raw = value ?? '';
    if (TerminalId.normalize(raw) != null) {
      return null;
    }
    if (raw.trim().isEmpty) {
      return 'Ingrese el identificador de la terminal.';
    }
    return 'El identificador tiene como máximo 8 caracteres.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await context.read<TerminalIdStore>().save(_controller.text);
    if (!mounted) return;
    if (saved == null) return;
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const AuthHeader(showLogo: false, useSolidaridadLogo: true),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AuthCard(
                    child: _ready
                        ? Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: AppSpacing.sm),
                                const Text(
                                  'Identificador de terminal',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.screenTitle,
                                ),
                                SizedBox(height: AppSpacing.md),
                                const Text(
                                  'Código de hasta 8 caracteres asignado a este equipo. Se usa en el inicio de sesión y en las ventas.',
                                  textAlign: TextAlign.center,
                                ),
                                const Divider(height: 40),
                                Text(
                                  'Terminal',
                                  style: AppTextStyles.formLabel.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _controller,
                                  style: const TextStyle(fontSize: 22),
                                  maxLength: TerminalId.maxLength,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  validator: _validate,
                                  decoration: const InputDecoration(
                                    hintText: '05000001',
                                    prefixIcon: Icon(
                                      Icons.point_of_sale_outlined,
                                      size: 24,
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _save(),
                                ),
                                SizedBox(height: AppSpacing.lg),
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _save,
                                    child: const Text('GUARDAR'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('VOLVER'),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
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
