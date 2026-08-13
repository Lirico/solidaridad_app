import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../psdk/psdk_bridge.dart';
import '../cubit/sales_cubit.dart';
import '../widgets/waiting_for_card_bottom_bar.dart';
import '../widgets/waiting_for_card_content.dart';
import '../widgets/waiting_for_card_header.dart';

class WaitingForCardScreen extends StatefulWidget {
  const WaitingForCardScreen({super.key});

  @override
  State<WaitingForCardScreen> createState() => _WaitingForCardScreenState();
}

class _WaitingForCardScreenState extends State<WaitingForCardScreen> {
  final PsdkBridge _psdk = PsdkBridge();
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _startReading();
  }

  @override
  void dispose() {
    _psdk.tearDown();
    super.dispose();
  }

  /// Inicializa el PSDK y luego espera la lectura de banda magnética.
  Future<void> _startReading() async {
    if (_reading) return;
    setState(() => _reading = true);

    try {
      // 1. Inicializar el PaymentSDK (despierta el lector Verifone).
      await _psdk.initialize();

      // 2. Esperar a que el SDK quede listo (evento sdiReady) antes de leer.
      //    initialize() es asíncrono: retorna de inmediato con sdiReady=false
      //    y el SDK recién queda listo cuando llega handleStatus con SUCCESS.
      final bool ready = await _waitForSdkReady(timeoutSec: 20);
      if (!mounted) return;

      if (!ready) {
        _showError('No se pudo inicializar el lector de tarjetas. Reintente.');
        return;
      }

      // 3. Esperar la lectura de banda (hasta 30 segundos).
      final result = await _psdk.readMsr(timeoutSec: 30);

      if (!mounted) return;

      // 3. Mapear los datos de la tarjeta.
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

      final Map<String, dynamic> tags = result['tags'] is Map
          ? Map<String, dynamic>.from(result['tags'])
          : {};
      final Map<String, dynamic> msr = result['msr'] is Map
          ? Map<String, dynamic>.from(result['msr'])
          : {};

      final String pan = (tags['pan'] ?? msr['panAscii'] ?? '') as String;
      final String track2 = (tags['track2'] ?? msr['track2'] ?? '') as String;

      if (pan.isEmpty) {
        _showError('No se pudo leer el número de tarjeta. Reintente.');
        return;
      }

      // El vencimiento puede venir en tags['expiry'] (YYMM) o, si viene vacío,
      // se extrae del track2 (formato ";PAN=EXPIRY?SERVICE" → "=3012").
      final String expiryYyMm = _extractExpiryYyMm(
        (tags['expiry'] ?? '') as String,
        track2,
      );

      // La banda magnética NO contiene CVV: se envía vacío.
      // El vencimiento viene en formato YYMM (ej. "3012") y showReview
      // espera MMYY (ej. "1230").
      final String expirationDate = _yyMmToMmYy(expiryYyMm);

      // 4. Guardar los datos en el cubit y navegar a la revisión.
      // La lectura fue por banda magnética: entry_mode "022". Se envía el PAN
      // (DE2) + vencimiento (DE14) en lugar del track2 (DE35), porque el track2
      // que devuelve esta terminal trae un PAN que no coincide con el
      // registrado (ej. "4606300701400740" en vez de "6063007014007403"). El
      // autorizador usa el PAN explícito cuando viene presente.
      final cubit = context.read<SalesCubit>();
      final state = cubit.state;

      cubit.showReview(
        productCode: state.productCode,
        productLabel: state.productLabel,
        amount: state.amount,
        cardNumber: pan,
        cvv: '',
        expirationDate: expirationDate,
        entryMode: '022',
        track2: null,
      );

      Navigator.pushNamed(context, AppRoutes.saleReview);
    } catch (_) {
      if (!mounted) return;
      _showError('Error al inicializar el lector de tarjetas. Reintente.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Convierte vencimiento de formato YYMM (ej. "3012") a MMYY (ej. "1230").
  String _yyMmToMmYy(String yyMm) {
    if (yyMm.length != 4) return yyMm;
    return yyMm.substring(2) + yyMm.substring(0, 2);
  }

  /// Devuelve el vencimiento en formato YYMM.
  ///
  /// Si [tagsExpiry] ya trae un valor (YYMM) se usa tal cual. Si viene vacío,
  /// se extrae del [track2] cuyo formato es ";PAN=EXPIRY?SERVICE" (ej.
  /// ";6063007014007403=3012?8" → "3012").
  String _extractExpiryYyMm(String tagsExpiry, String track2) {
    if (tagsExpiry.isNotEmpty) return tagsExpiry;

    final int eq = track2.indexOf('=');
    final int q = track2.indexOf('?', eq + 1);
    if (eq >= 0 && q > eq) {
      final String expiry = track2.substring(eq + 1, q);
      if (expiry.length == 4) return expiry;
    }
    return '';
  }

  /// Espera hasta que el PaymentSDK emita el evento `sdiReady` (o `success`).
  ///
  /// `initialize()` es asíncrono: retorna de inmediato con `sdiReady=false` y
  /// el SDK recién queda listo cuando llega `handleStatus` con SUCCESS. Este
  /// método escucha [PsdkBridge.statusEvents] hasta que eso ocurra o se agote
  /// [timeoutSec].
  Future<bool> _waitForSdkReady({int timeoutSec = 20}) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryOrange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const WaitingForCardHeader(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Contenido principal blanco con bordes redondeados
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: WaitingForCardContent(
                onCancelOperation: () => Navigator.maybePop(context),
              ),
            ),
          ),
          // Botón Volver fijo en la parte inferior (fuera del contenedor blanco)
          WaitingForCardBottomBar(
            onBackPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}
