import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/sale_model.dart';
import 'sales_repository.dart';

/// Catálogo compartido de productos para la sesión activa.
///
/// La primera carga se inicia después del login/restauración. Los consumidores
/// llaman [getOrLoad], que devuelve la copia vigente o inicializa el store en
/// ese momento si todavía no hubo una carga exitosa. Un solo request puede
/// estar activo por sesión.
class ProductCatalogStore {
  ProductCatalogStore({
    required this._repository,
    this._refreshInterval = const Duration(minutes: 15),
    this._retryDelay = const Duration(seconds: 1),
    int refreshAttempts = 3,
    Future<void> Function(Duration)? retryWait,
    Timer Function(Duration, void Function())? schedule,
    void Function(String)? log,
  }) : _refreshAttempts = refreshAttempts < 1 ? 1 : refreshAttempts,
       _retryWait = retryWait ?? Future<void>.delayed,
       _schedule =
           schedule ?? ((duration, callback) => Timer(duration, callback)),
       _log = log ?? debugPrint;

  final SalesRepository _repository;
  final Duration _refreshInterval;
  final Duration _retryDelay;
  final int _refreshAttempts;
  final Future<void> Function(Duration) _retryWait;
  final Timer Function(Duration, void Function()) _schedule;
  final void Function(String) _log;

  List<ProductInfo>? _current;
  String? _activeToken;
  int _generation = 0;
  Timer? _refreshTimer;
  Future<List<ProductInfo>>? _inFlight;
  Future<void> Function()? _onSessionExpired;

  List<ProductInfo>? get current => _current;

  bool get isInitialized => _current != null;

  /// Activa una sesión, carga el catálogo inmediatamente y programa el próximo
  /// refresco. Los fallos transitorios conservan la última copia disponible.
  Future<void> start({
    required String token,
    Future<void> Function()? onSessionExpired,
  }) async {
    if (_activeToken != token) {
      stop(clear: true);
      _activeToken = token;
      _generation++;
    }
    _onSessionExpired = onSessionExpired;
    final generation = _generation;

    if (_current == null) {
      try {
        await _load(token, generation, force: true);
      } on SessionExpiredException {
        return;
      } on DataLoadException catch (error) {
        if (_isCurrent(token, generation)) {
          _log(
            'No se pudo cargar el catálogo de productos (${error.message}). '
            'Se reintentará al acceder o en la próxima ventana.',
          );
        }
      }
    }
    _scheduleNext(token, generation);
  }

  /// Devuelve el catálogo de la sesión. Si aún no está inicializado, lo carga
  /// en el momento; llamadas concurrentes comparten el mismo request.
  Future<List<ProductInfo>> getOrLoad({required String token}) async {
    if (_activeToken != token) {
      stop(clear: true);
      _activeToken = token;
      _generation++;
    }
    final generation = _generation;
    final cached = _current;
    if (cached != null) {
      _scheduleNext(token, generation);
      return cached;
    }

    final loaded = await _load(token, generation, force: false);
    _scheduleNext(token, generation);
    return loaded;
  }

  void stop({required bool clear}) {
    _generation++;
    _activeToken = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _inFlight = null;
    _onSessionExpired = null;
    if (clear) _current = null;
  }

  Future<List<ProductInfo>> _load(
    String token,
    int generation, {
    required bool force,
  }) {
    if (!force && _current != null) {
      return Future<List<ProductInfo>>.value(_current!);
    }
    final active = _inFlight;
    if (active != null) return active;

    late final Future<List<ProductInfo>> request;
    request = _fetchWithRetry(token, generation).whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
    _inFlight = request;
    return request;
  }

  Future<List<ProductInfo>> _fetchWithRetry(
    String token,
    int generation,
  ) async {
    DataLoadException? lastError;
    for (var attempt = 1; attempt <= _refreshAttempts; attempt++) {
      if (!_isCurrent(token, generation)) {
        throw const DataLoadException('La sesión cambió durante la carga.');
      }
      try {
        final products = await _repository.fetchProducts(token: token);
        if (products.isEmpty) {
          throw const DataLoadException(
            'El catálogo de productos está vacío. Reintente.',
          );
        }
        if (!_isCurrent(token, generation)) {
          throw const DataLoadException('La sesión cambió durante la carga.');
        }
        _current = List<ProductInfo>.unmodifiable(products);
        return _current!;
      } on SessionExpiredException {
        await _expireSession(token, generation);
        rethrow;
      } on DataLoadException catch (error) {
        lastError = error;
        if (attempt == _refreshAttempts) break;
        await _retryWait(_retryDelay * attempt);
      }
    }
    throw lastError ??
        const DataLoadException('No se pudo cargar el catálogo.');
  }

  Future<void> _expireSession(String token, int generation) async {
    if (!_isCurrent(token, generation)) return;
    final callback = _onSessionExpired;
    stop(clear: true);
    if (callback != null) await callback();
  }

  void _scheduleNext(String token, int generation) {
    if (!_isCurrent(token, generation)) return;
    if (_refreshTimer?.isActive ?? false) return;
    _refreshTimer = _schedule(_refreshInterval, () {
      _refreshTimer = null;
      unawaited(_refreshAndScheduleNext(token, generation));
    });
  }

  Future<void> _refreshAndScheduleNext(String token, int generation) async {
    try {
      await _load(token, generation, force: true);
    } on SessionExpiredException {
      return;
    } on DataLoadException catch (error) {
      if (_isCurrent(token, generation)) {
        _log(
          'No se pudo refrescar el catálogo de productos (${error.message}). '
          'Se conserva el valor local hasta la próxima ventana.',
        );
      }
    } finally {
      _scheduleNext(token, generation);
    }
  }

  bool _isCurrent(String token, int generation) {
    return _activeToken == token && _generation == generation;
  }
}
