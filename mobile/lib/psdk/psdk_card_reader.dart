import 'dart:async';

import 'msr_card_data.dart';
import 'psdk_bridge.dart';

/// Resultado tipado de una lectura de banda magnética (MSR).
///
/// `sealed` para que el consumidor deba contemplar explícitamente ambos casos
/// (`CardReadSuccess` / `CardReadFailure`) y no dependa de la forma interna
/// del payload del bridge (`hasClearData`, `timedOut`, `tags`, `msr`).
sealed class CardReadResult {
  const CardReadResult();
}

/// Lectura de banda exitosa con los datos ya parseados.
class CardReadSuccess extends CardReadResult {
  const CardReadSuccess(this.data);

  /// Datos de tarjeta listos para mapear a la venta / consulta de saldo.
  final MsrCardData data;
}

/// Motivo por el que una lectura de banda falló.
enum CardReadFailureReason {
  /// El PSDK no quedó listo (`sdiReady`) dentro del timeout.
  notReady,

  /// No se detectó ninguna tarjeta antes del timeout.
  timedOut,

  /// La tarjeta se leyó pero sin datos claros (`hasClearData == false`).
  unreadable,

  /// Se leyó pero el PAN vino vacío.
  badPan,

  /// Excepción durante la inicialización o lectura.
  exception,
}

/// Lectura de banda fallida, con un [message] listo para mostrar al usuario.
class CardReadFailure extends CardReadResult {
  const CardReadFailure(this.reason, this.message);

  final CardReadFailureReason reason;
  final String message;

  @override
  String toString() => 'CardReadFailure($reason): $message';
}

/// Sesión de lectura de tarjeta por banda magnética sobre el PSDK Verifone.
///
/// Es la **fuente única de verdad** del ciclo delicado del lector:
/// inicialización, espera de `sdiReady` con guard de race-condition, lectura
/// MSR, parseo a [MsrCardData] y limpieza (`cancelReadMsr` → `tearDown`).
/// La usan el flujo de venta, el de consulta de saldo y `ReceiptPrinter`,
/// para que un fix del ciclo no haya que aplicarlo en cada pantalla.
///
/// Compone (no reemplaza) a [PsdkBridge]: recibe un bridge inyectable para
/// poder testear el ciclo con un doble, sin hardware.
class PsdkCardReader {
  PsdkCardReader({PsdkBridge? psdk}) : _psdk = psdk ?? PsdkBridge();

  final PsdkBridge _psdk;

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
  ///
  /// Con [initializeIfNeeded] en `true`, si el SDK aún no está listo se llama a
  /// [PsdkBridge.initialize] antes de escuchar el stream (lo usa la impresión,
  /// que no inicializa por su cuenta). Las pantallas de lectura llaman a
  /// `initialize()` primero y luego a este método, por eso el default es
  /// `false`.
  Future<bool> ensureReady({
    int timeoutSec = 20,
    bool initializeIfNeeded = false,
  }) async {
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

    // 1b. Si el caller no inicializó por su cuenta, hacerlo antes de esperar.
    if (initializeIfNeeded) {
      try {
        await _psdk.initialize();
      } catch (_) {
        // initialize() es async y no lanza en el flujo normal; si falla, el
        // stream nunca emitirá y el timeout de abajo devuelve false.
      }
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

  /// Inicializa el SDK y espera una lectura de banda.
  ///
  /// [readyTimeoutSec] acota la espera de `sdiReady`; [timeoutSec] acota la
  /// lectura de banda.
  ///
  /// Devuelve [CardReadSuccess] con los datos parseados o un [CardReadFailure]
  /// con el motivo y un mensaje listo para mostrar. Nunca lanza: las
  /// excepciones se convierten en [CardReadFailureReason.exception].
  Future<CardReadResult> readCard({
    int timeoutSec = 30,
    int readyTimeoutSec = 20,
  }) async {
    try {
      // 1. Inicializar el PaymentSDK (despierta el lector Verifone).
      await _psdk.initialize();

      // 2. Esperar a que el SDK quede listo (evento sdiReady) antes de leer.
      final bool ready = await ensureReady(timeoutSec: readyTimeoutSec);
      if (!ready) {
        return const CardReadFailure(
          CardReadFailureReason.notReady,
          'No se pudo inicializar el lector de tarjetas. Reintente.',
        );
      }

      // 3. Esperar la lectura de banda (hasta [timeoutSec] segundos).
      final result = await _psdk.readMsr(timeoutSec: timeoutSec);

      // El bridge nativo setea `ok` solo cuando code == OK, pero en esta
      // terminal la lectura devuelve ERR_EXECUTION con datos claros en `tags`
      // (hasClearData == true). Por eso el éxito se determina por hasClearData.
      final bool hasClearData = result['hasClearData'] == true;
      final bool timedOut = result['timedOut'] == true;

      if (!hasClearData || timedOut) {
        return CardReadFailure(
          timedOut
              ? CardReadFailureReason.timedOut
              : CardReadFailureReason.unreadable,
          timedOut
              ? 'No se detectó ninguna tarjeta. Reintente.'
              : 'No se pudo leer la tarjeta. Reintente.',
        );
      }

      // 4. Parsear los datos de la tarjeta en un modelo tipado.
      final MsrCardData data = MsrCardData.fromBridge(result);
      if (data.pan.isEmpty) {
        return const CardReadFailure(
          CardReadFailureReason.badPan,
          'No se pudo leer el número de tarjeta. Reintente.',
        );
      }

      return CardReadSuccess(data);
    } catch (_) {
      return const CardReadFailure(
        CardReadFailureReason.exception,
        'Error al inicializar el lector de tarjetas. Reintente.',
      );
    }
  }

  /// Cancela una lectura MSR en curso y apaga el SDK.
  ///
  /// Llama a [PsdkBridge.cancelReadMsr] y **luego** a [PsdkBridge.tearDown],
  /// en ese orden, para no apagar el SDK con una lectura todavía activa.
  Future<void> cancel() async {
    await _psdk.cancelReadMsr();
    await _psdk.tearDown();
  }
}
