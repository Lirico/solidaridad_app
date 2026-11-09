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

/// Lee banda usando la sesión PSDK compartida con la impresora.
/// La cancelación aborta la lectura activa sin cerrar una sesión sana.
class PsdkCardReader {
  PsdkCardReader({PsdkBridge? psdk}) : _psdk = psdk ?? PsdkBridge();

  final PsdkBridge _psdk;

  /// Indica si esta instancia aún puede solicitar la cancelación de su lectura.
  bool _ownsSession = false;
  bool _reading = false;

  /// El `dispose` de la pantalla pidió abortar. Corta los reintentos de
  /// arranque para no volver a crear el SDK después de un [cancel].
  bool _cancelRequested = false;

  /// Liberación en curso. Quien llegue mientras corre se une a este mismo
  /// `Future`, para no encadenar dos `tearDown`.
  Future<void>? _releaseInFlight;

  /// Espera hasta que el PaymentSDK emita `sdiReady`.
  ///
  /// `initialize()` es asíncrono: retorna de inmediato con `sdiReady=false` y
  /// el SDK recién queda listo cuando llega `handleStatus` con el manager de
  /// SDI. Este método escucha [PsdkBridge.statusEvents] hasta que eso ocurra
  /// o se agote [timeoutSec].
  ///
  /// `success` solo no alcanza. Un callback puede decir SUCCESS cuando
  /// `sdiManager` todavía es null, o llegar tarde de un SDK ya apagado. En
  /// ambos casos `readMsr` y `printHtml` fallan con `PSDK_NOT_READY`.
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
    final initialStatus = await _psdk.getStatus();
    if (initialStatus['sdiReady'] == true) return true;
    final completer = Completer<bool>();
    final sub = _psdk.statusEvents.listen((event) {
      if (event['sdiReady'] == true && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    try {
      // Subscribe first, then check the snapshot, so no callback can be missed.
      var status = await _psdk.getStatus();
      if (status['sdiReady'] == true) return true;
      if (initializeIfNeeded) {
        await _psdk.initialize();
        status = await _psdk.getStatus();
        if (status['sdiReady'] == true) return true;
      }
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
  /// lectura de banda. El arranque se reintenta hasta [initAttempts] veces
  /// (con [initRetryDelay] entre intentos) antes de devolver [notReady] o
  /// [exception]. Un timeout de pasada no se reintenta: el lector ya estaba
  /// listo.
  ///
  /// Devuelve [CardReadSuccess] con los datos parseados o un [CardReadFailure]
  /// con el motivo y un mensaje listo para mostrar. Nunca lanza: las
  /// excepciones se convierten en [CardReadFailureReason.exception].
  Future<CardReadResult> readCard({
    int timeoutSec = 30,
    int readyTimeoutSec = 20,
    int initAttempts = 3,
    Duration initRetryDelay = const Duration(milliseconds: 400),
  }) async {
    _cancelRequested = false;
    _ownsSession = true;
    try {
      final CardReadFailure? initFailure = await _bringReaderOnline(
        readyTimeoutSec: readyTimeoutSec,
        initAttempts: initAttempts,
        initRetryDelay: initRetryDelay,
      );
      if (initFailure != null) return initFailure;

      if (_cancelRequested) {
        return const CardReadFailure(
          CardReadFailureReason.exception,
          'Lectura cancelada.',
        );
      }
      _reading = true;
      final Map<String, dynamic> result;
      try {
        result = await _psdk.readMsr(timeoutSec: timeoutSec);
      } finally {
        _reading = false;
      }
      if (_cancelRequested || result['cancelled'] == true) {
        return const CardReadFailure(
          CardReadFailureReason.exception,
          'Lectura cancelada.',
        );
      }

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
    } finally {
      _ownsSession = false;
    }
  }

  /// Arranca el lector. Reintenta solo esta fase: un fallo de pasada de
  /// tarjeta no vuelve a entrar acá.
  ///
  /// Devuelve `null` con la sesión todavía abierta cuando el SDK quedó listo.
  /// Si agota los intentos o [cancel] cortó el ciclo, devuelve el fallo y deja
  /// la sesión liberada.
  Future<CardReadFailure?> _bringReaderOnline({
    required int readyTimeoutSec,
    required int initAttempts,
    required Duration initRetryDelay,
  }) async {
    const CardReadFailure notReady = CardReadFailure(
      CardReadFailureReason.notReady,
      'No se pudo inicializar el lector de tarjetas. Reintente.',
    );
    const CardReadFailure initError = CardReadFailure(
      CardReadFailureReason.exception,
      'Error al inicializar el lector de tarjetas. Reintente.',
    );

    CardReadFailure? failure;
    final int attempts = initAttempts < 1 ? 1 : initAttempts;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (_cancelRequested) {
        await _release();
        return failure ?? initError;
      }

      _ownsSession = true;
      var ready = false;
      try {
        await _psdk.initialize();
        ready = await ensureReady(timeoutSec: readyTimeoutSec);
        if (!ready) failure = notReady;
      } catch (_) {
        ready = false;
        failure = initError;
      }

      if (_cancelRequested) {
        await _release();
        return failure ?? initError;
      }
      if (ready) return null;

      try {
        await _psdk.tearDown().timeout(const Duration(seconds: 10));
      } catch (_) {
        return initError;
      }
      if (attempt < attempts - 1) {
        await _pauseForRetry(initRetryDelay);
      }
    }
    return failure ?? notReady;
  }

  /// Espera [delay] entre arranques, en pasos cortos, para que [cancel]
  /// corte el ciclo sin esperar los 400 ms enteros.
  Future<void> _pauseForRetry(Duration delay) async {
    if (delay <= Duration.zero || _cancelRequested) return;
    final DateTime end = DateTime.now().add(delay);
    while (!_cancelRequested && DateTime.now().isBefore(end)) {
      final Duration remaining = end.difference(DateTime.now());
      final Duration step = remaining < const Duration(milliseconds: 50)
          ? remaining
          : const Duration(milliseconds: 50);
      if (step <= Duration.zero) return;
      await Future<void>.delayed(step);
    }
  }

  /// Solicita abortar la lectura activa; no cierra la sesión compartida.
  Future<void> cancel() {
    _cancelRequested = true;
    return _release();
  }

  Future<void> _release() {
    if (!_ownsSession) return _releaseInFlight ?? Future<void>.value();
    _ownsSession = false;
    if (!_reading) return Future<void>.value();
    final future = _cancelRead();
    _releaseInFlight = future;
    return future.whenComplete(() {
      if (identical(_releaseInFlight, future)) _releaseInFlight = null;
    });
  }

  Future<void> _cancelRead() async {
    try {
      await _psdk.cancelReadMsr();
    } catch (_) {
      // The operation's own result remains authoritative.
    }
  }
}
