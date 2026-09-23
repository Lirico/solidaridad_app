import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../psdk/psdk_card_reader.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/presentation/widgets/waiting_for_card_content.dart';
import '../cubit/balance_cubit.dart';

class BalanceWaitingForCardScreen extends StatefulWidget {
  const BalanceWaitingForCardScreen({super.key});

  @override
  State<BalanceWaitingForCardScreen> createState() =>
      _BalanceWaitingForCardScreenState();
}

class _BalanceWaitingForCardScreenState
    extends State<BalanceWaitingForCardScreen> {
  final PsdkCardReader _reader = PsdkCardReader();
  bool _reading = false;
  String? _errorMessage;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _startReading();
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancelar la lectura en curso antes de apagar el SDK (cancelReadMsr →
    // tearDown, en ese orden dentro del servicio), para no hacer tearDown con
    // un readMsr todavía activo.
    _reader.cancel();
    super.dispose();
  }

  /// Dispara la lectura de banda y navega a la revisión de saldo.
  ///
  /// Todo el ciclo delicado del PSDK (initialize, espera de `sdiReady` con
  /// guard de race-condition, `readMsr`, parseo y limpieza) vive en
  /// [PsdkCardReader], compartido con el flujo de venta.
  Future<void> _startReading() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _errorMessage = null;
    });

    try {
      final CardReadResult result = await _reader.readCard();
      if (!mounted || _disposed) return;

      switch (result) {
        case CardReadSuccess(:final data):
          // Guardar los datos en el cubit y navegar a la revisión. La lectura
          // fue por banda magnética: entry_mode "022" y sin track2 (se envían
          // PAN + vencimiento explícitos).
          context.read<BalanceCubit>().setCardData(
            cardNumber: data.pan,
            expirationDate: data.expiryMmYy,
            entryMode: '022',
            track2: null,
          );
          Navigator.pushNamed(context, AppRoutes.balanceReview);
        case CardReadFailure(:final message):
          _showError(message);
      }
    } finally {
      if (mounted && !_disposed) setState(() => _reading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryOrange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onBackPressed() {
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Consultar Saldo',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: AppBottomNavBar(onBack: _onBackPressed),
      body: AppSheetPanel(
        child: WaitingForCardContent(
          errorMessage: _errorMessage,
          onRetry: _errorMessage != null ? _startReading : null,
          onCancelOperation: _onBackPressed,
        ),
      ),
    );
  }
}
