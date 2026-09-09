import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../psdk/psdk_bridge.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/domain/msr_card_data.dart';
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
  final PsdkBridge _psdk = PsdkBridge();
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
    _psdk.cancelReadMsr();
    _psdk.tearDown();
    super.dispose();
  }

  Future<void> _startReading() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _errorMessage = null;
    });

    try {
      await _psdk.initialize();

      final bool ready = await _waitForSdkReady(timeoutSec: 20);
      if (!mounted || _disposed) return;

      if (!ready) {
        _showError('No se pudo inicializar el lector de tarjetas. Reintente.');
        return;
      }

      final result = await _psdk.readMsr(timeoutSec: 30);
      if (!mounted || _disposed) return;

      final bool hasClearData = result['hasClearData'] == true;
      final bool timedOut = result['timedOut'] == true;

      if (!hasClearData || timedOut) {
        _showError(
          timedOut
              ? 'No se detectó ninguna tarjeta. Reintente.'
              : 'No se pudo leer la tarjeta. Reintente.',
        );
        return;
      }

      final MsrCardData data = MsrCardData.fromBridge(result);
      if (data.pan.isEmpty) {
        _showError('No se pudo leer el número de tarjeta. Reintente.');
        return;
      }

      context.read<BalanceCubit>().setCardData(
        cardNumber: data.pan,
        expirationDate: data.expiryMmYy,
        entryMode: '022',
        track2: null,
      );
      Navigator.pushNamed(context, AppRoutes.balanceReview);
    } catch (_) {
      if (!mounted || _disposed) return;
      _showError('Error al inicializar el lector de tarjetas. Reintente.');
    } finally {
      if (mounted && !_disposed) setState(() => _reading = false);
    }
  }

  Future<bool> _waitForSdkReady({int timeoutSec = 20}) async {
    try {
      final Map<String, dynamic> status = await _psdk.getStatus();
      final bool alreadyReady =
          status['sdiReady'] == true || status['initialized'] == true;
      if (alreadyReady) return true;
    } catch (_) {
      // Si getStatus falla, seguimos y esperamos el stream.
    }

    final completer = Completer<bool>();
    StreamSubscription<Map<String, dynamic>>? sub;

    sub = _psdk.statusEvents.listen((event) {
      final bool ready = event['sdiReady'] == true || event['success'] == true;
      if (ready && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    try {
      return await completer.future.timeout(
        Duration(seconds: timeoutSec),
        onTimeout: () => false,
      );
    } finally {
      await sub.cancel();
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
