import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../../psdk/psdk_bridge.dart';
import '../../domain/msr_card_data.dart';
import '../cubit/sales_cubit.dart';
import '../widgets/waiting_for_card_content.dart';

class WaitingForCardScreen extends StatefulWidget {
  const WaitingForCardScreen({super.key});

  @override
  State<WaitingForCardScreen> createState() => _WaitingForCardScreenState();
}

class _WaitingForCardScreenState extends State<WaitingForCardScreen> {
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
    // Cancelar la lectura en curso antes de apagar el SDK, para no hacer
    // tearDown con un readMsr todavía activo.
    _psdk.cancelReadMsr();
    _psdk.tearDown();
    super.dispose();
  }

  /// Inicializa el PSDK y luego espera la lectura de banda magnética.
  Future<void> _startReading() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _errorMessage = null;
    });

    try {
      // 1. Inicializar el PaymentSDK (despierta el lector Verifone).
      await _psdk.initialize();

      // 2. Esperar a que el SDK quede listo (evento sdiReady) antes de leer.
      //    initialize() es asíncrono: retorna de inmediato con sdiReady=false
      //    y el SDK recién queda listo cuando llega handleStatus con SUCCESS.
      final bool ready = await _waitForSdkReady(timeoutSec: 20);
      if (!mounted || _disposed) return;

      if (!ready) {
        _showError('No se pudo inicializar el lector de tarjetas. Reintente.');
        return;
      }

      // 3. Esperar la lectura de banda (hasta 30 segundos).
      final result = await _psdk.readMsr(timeoutSec: 30);

      if (!mounted || _disposed) return;

      // El bridge nativo setea `ok` solo cuando code == OK, pero en esta
      // terminal la lectura devuelve ERR_EXECUTION con datos claros en `tags`
      // (hasClearData == true). Por eso el éxito se determina por hasClearData.
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

      // 4. Parsear los datos de la tarjeta en un modelo tipado.
      final MsrCardData data = MsrCardData.fromBridge(result);
      if (data.pan.isEmpty) {
        _showError('No se pudo leer el número de tarjeta. Reintente.');
        return;
      }

      // 5. Guardar los datos en el cubit y navegar a la revisión.
      context.read<SalesCubit>().showReviewFromMsr(data);
      Navigator.pushNamed(context, AppRoutes.saleReview);
    } catch (_) {
      if (!mounted || _disposed) return;
      _showError('Error al inicializar el lector de tarjetas. Reintente.');
    } finally {
      if (mounted && !_disposed) setState(() => _reading = false);
    }
  }

  /// Espera hasta que el PaymentSDK emita el evento `sdiReady` (o `success`).
  ///
  /// `initialize()` es asíncrono: retorna de inmediato con `sdiReady=false` y
  /// el SDK recién queda listo cuando llega `handleStatus` con SUCCESS. Este
  /// método escucha [PsdkBridge.statusEvents] hasta que eso ocurra o se agote
  /// [timeoutSec].
  ///
  /// Para evitar una race condition (el evento `sdiReady` puede haber llegado
  /// antes de suscribirnos al stream), primero se consulta el estado actual con
  /// [PsdkBridge.getStatus] y solo si aún no está listo se escucha el stream.
  Future<bool> _waitForSdkReady({int timeoutSec = 20}) async {
    // 1. Chequear el estado actual: si el SDK ya quedó listo (el evento pudo
    //    haber pasado antes de suscribirnos), no hace falta esperar el stream.
    try {
      final Map<String, dynamic> status = await _psdk.getStatus();
      final bool alreadyReady =
          status['sdiReady'] == true || status['initialized'] == true;
      if (alreadyReady) return true;
    } catch (_) {
      // Si getStatus falla, seguimos y esperamos el stream.
    }

    // 2. Si aún no está listo, escuchar el stream hasta que llegue el evento.
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
        title: 'Nueva Operación',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      // La flecha "atrás" cancela la operación y la lectura de banda (el pop
      // dispara dispose() → cancelReadMsr + tearDown del PSDK).
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
