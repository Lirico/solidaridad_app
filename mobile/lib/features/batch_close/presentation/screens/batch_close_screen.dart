import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../domain/batch_close_model.dart';
import '../cubit/batch_close_cubit.dart';
import '../cubit/batch_close_state.dart';
import '../widgets/batch_close_content.dart';

/// Cierre de Lote: corte administrativo del lote actual de la terminal.
class BatchCloseScreen extends StatefulWidget {
  const BatchCloseScreen({super.key});

  @override
  State<BatchCloseScreen> createState() => _BatchCloseScreenState();
}

class _BatchCloseScreenState extends State<BatchCloseScreen> {
  String? _closeIdempotencyKey;
  @override
  void initState() {
    super.initState();
    _loadCurrentBatch();
  }

  void _loadCurrentBatch() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthSuccess && authState.user != null) {
      context.read<BatchCloseCubit>().loadCurrentBatch(
        token: authState.user!.token,
      );
    }
  }

  Future<void> _onCloseBatch() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthSuccess || authState.user == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar lote'),
        content: const Text(
          'Las ventas de este lote quedarán cerradas y ya no podrán anularse desde la terminal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _closeIdempotencyKey ??=
        'batch-close-${DateTime.now().microsecondsSinceEpoch}';
    await context.read<BatchCloseCubit>().closeCurrentBatch(
      token: authState.user!.token,
      idempotencyKey: _closeIdempotencyKey!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Cierre de Lote',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: BlocListener<BatchCloseCubit, BatchCloseState>(
          listener: (context, state) {
            if (state is BatchCloseSessionExpired) {
              context.read<AuthCubit>().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            }
            if (state is BatchCloseClosed) {
              _closeIdempotencyKey = null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Lote cerrado: ${state.operations.length} operaciones incluidas.',
                  ),
                ),
              );
              _loadCurrentBatch();
            }
            if (state is BatchCloseCloseFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: BlocBuilder<BatchCloseCubit, BatchCloseState>(
            builder: (context, state) {
              if (state is BatchCloseLoading || state is BatchCloseInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is BatchCloseFailed) {
                return _BatchCloseError(
                  message: state.message,
                  onRetry: _loadCurrentBatch,
                );
              }

              final BatchSummary? summary = switch (state) {
                BatchCloseLoaded(:final summary) => summary,
                BatchCloseClosing(:final summary) => summary,
                BatchCloseCloseFailed(:final summary) => summary,
                _ => null,
              };

              if (summary == null) return const SizedBox.shrink();

              return BatchCloseContent(
                summary: summary,
                onCloseBatch: _onCloseBatch,
                isClosing: state is BatchCloseClosing,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Estado de error del resumen: mensaje real + REINTENTAR (sin fallback mudo).
class _BatchCloseError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BatchCloseError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(
            Icons.wifi_off_outlined,
            size: 64,
            color: AppColors.warningOrange,
          ),
          const SizedBox(height: 12),
          const Text(
            'No se pudo obtener el resumen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.warningOrange,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
              ),
              child: const Text(
                'REINTENTAR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
