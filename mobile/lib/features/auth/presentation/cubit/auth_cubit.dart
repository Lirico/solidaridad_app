import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../data/merchant_store.dart';
import '../../data/session_store.dart';
import '../../domain/access_token.dart';
import '../../domain/auth_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final MerchantStore _merchantStore;
  final SessionStore _sessionStore;
  final Duration _merchantRefreshInterval;
  final Duration _merchantRetryDelay;
  final int _merchantRefreshAttempts;
  final Future<void> Function(Duration) _retryWait;
  final Timer Function(Duration, void Function()) _schedule;
  final void Function(String) _log;
  final DateTime Function() _now;
  PersistedSession? _session;
  int _merchantRefreshGeneration = 0;
  String? _activeMerchantToken;
  Timer? _merchantRefreshTimer;

  AuthCubit({
    required this._authRepository,
    MerchantStore? merchantStore,
    SessionStore? sessionStore,
    this._merchantRefreshInterval = const Duration(minutes: 15),
    this._merchantRetryDelay = const Duration(seconds: 1),
    int merchantRefreshAttempts = 3,
    Future<void> Function(Duration)? retryWait,
    Timer Function(Duration, void Function())? schedule,
    void Function(String)? log,
    DateTime Function()? now,
  }) : _merchantStore = merchantStore ?? MerchantStore(),
       _sessionStore = sessionStore ?? MemorySessionStore(),
       _merchantRefreshAttempts = merchantRefreshAttempts < 1
           ? 1
           : merchantRefreshAttempts,
       _retryWait = retryWait ?? Future<void>.delayed,
       _schedule =
           schedule ?? ((duration, callback) => Timer(duration, callback)),
       _log = log ?? debugPrint,
       _now = now ?? DateTime.now,
       super(const AuthInitial());

  Merchant? get merchant => _merchantStore.current;

  /// Recupera la sesión guardada. Un token sin `exp` sigue vigente; uno con
  /// `exp` vencido, o un registro ilegible, vuelve al login.
  Future<void> restore() async {
    PersistedSession? saved;
    try {
      saved = await _sessionStore.read();
    } catch (error) {
      _log('No se pudo leer la sesión guardada ($error).');
    }
    if (isClosed) return;
    if (saved == null ||
        accessTokenStatus(saved.user.token, now: _now()) !=
            AccessTokenStatus.valid) {
      if (saved != null) await _clearStoredSession();
      _session = null;
      _merchantStore.clear();
      if (!isClosed) emit(const AuthInitial());
      return;
    }

    await _persist(saved);
    if (isClosed) return;
    emit(_successFrom(saved));
    _startMerchantRefresh(saved.user);
  }

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    await _dropMemoryAndStorage();
    emit(const AuthLoading());

    final response = await _authRepository.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );
    if (isClosed) return;

    if (response.isSuccess && response.user != null) {
      final session = PersistedSession(
        user: response.user!,
        mustChangePassword: response.mustChangePassword,
        merchant: response.merchant,
      );
      await _persist(session);
      if (isClosed) return;
      emit(_successFrom(session, message: response.message));
      _startMerchantRefresh(response.user!);
    } else {
      emit(AuthError(message: response.message));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _dropMemoryAndStorage();
    emit(const AuthLoading());

    final response = await _authRepository.register(
      name: name,
      email: email,
      password: password,
    );
    if (isClosed) return;

    if (response.isSuccess && response.user != null) {
      emit(AuthSuccess(user: response.user!, message: response.message));
    } else {
      emit(AuthError(message: response.message));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final previous = state is AuthSuccess ? state as AuthSuccess : null;
    final baseline =
        _session ??
        (previous?.user == null
            ? null
            : PersistedSession(
                user: previous!.user!,
                mustChangePassword: previous.mustChangePassword,
                merchant: previous.merchant ?? _merchantStore.current,
              ));
    emit(const AuthLoading(loadingMessage: 'Cambiando contraseña...'));

    final response = await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      token: baseline?.user.token ?? previous?.user?.token ?? '',
    );
    if (isClosed) return;

    if (response.sessionExpired) {
      await _forget(AuthSessionExpired(message: response.message));
      return;
    }

    if (response.isSuccess) {
      final updated = (_session ?? baseline)?.copyWith(
        mustChangePassword: false,
      );
      if (updated != null) {
        await _persist(updated);
        if (isClosed) return;
        emit(_successFrom(updated, message: response.message));
      } else {
        emit(
          AuthSuccess(
            user: previous?.user,
            message: response.message,
            merchant: _merchantStore.current,
          ),
        );
      }
    } else {
      emit(AuthError(message: response.message));
    }
  }

  void _startMerchantRefresh(User user) {
    final generation = ++_merchantRefreshGeneration;
    _activeMerchantToken = user.token;
    _scheduleNextMerchantRefresh(user.token, generation);
  }

  void _scheduleNextMerchantRefresh(String token, int generation) {
    if (!_isCurrentMerchantSession(token, generation)) return;
    _merchantRefreshTimer?.cancel();
    _merchantRefreshTimer = _schedule(_merchantRefreshInterval, () {
      _merchantRefreshTimer = null;
      unawaited(_refreshAndScheduleNext(token, generation));
    });
  }

  Future<void> _refreshAndScheduleNext(String token, int generation) async {
    try {
      await _refreshMerchantSilently(token, generation);
    } catch (error) {
      if (_isCurrentMerchantSession(token, generation)) {
        _log(
          'Falló el ciclo de refresco del comercio ($error). '
          'Se conserva el valor local hasta la próxima ventana.',
        );
      }
    } finally {
      _scheduleNextMerchantRefresh(token, generation);
    }
  }

  Future<void> _refreshMerchantSilently(String token, int generation) async {
    MerchantLookup? lastLookup;
    var attempts = 0;

    while (attempts < _merchantRefreshAttempts &&
        _isCurrentMerchantSession(token, generation)) {
      attempts++;
      lastLookup = await _authRepository.fetchCurrentMerchant(token: token);
      if (!_isCurrentMerchantSession(token, generation)) return;

      final refreshed = lastLookup.merchant;
      if (refreshed != null) {
        final current = _session;
        final updated = current?.copyWith(merchant: refreshed);
        if (updated != null) {
          await _persist(updated);
        } else {
          _merchantStore.replace(refreshed);
        }
        if (!_isCurrentMerchantSession(token, generation) || isClosed) return;
        final visible = state;
        if (visible is AuthSuccess) {
          emit(
            AuthSuccess(
              user: visible.user,
              message: visible.message,
              mustChangePassword: visible.mustChangePassword,
              merchant: refreshed,
            ),
          );
        }
        return;
      }

      if (!lastLookup.unavailable || attempts == _merchantRefreshAttempts) {
        break;
      }
      await _retryWait(_merchantRetryDelay * attempts);
    }

    if (!_isCurrentMerchantSession(token, generation)) return;
    if (lastLookup?.sessionExpired == true) {
      _log('No se pudo refrescar el comercio: sesión no autorizada.');
      await _forget(
        const AuthSessionExpired(
          message: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
        ),
      );
      return;
    }
    final reason = lastLookup?.unavailable == true
        ? 'servicio no disponible tras $attempts intento(s)'
        : 'la cuenta no informó un comercio';
    _log(
      'No se pudo refrescar el comercio: $reason. '
      'Se conserva el valor local hasta la próxima ventana.',
    );
  }

  bool _isCurrentMerchantSession(String token, int generation) {
    final current = state;
    return !isClosed &&
        generation == _merchantRefreshGeneration &&
        _activeMerchantToken == token &&
        (current is! AuthSuccess || current.user?.token == token);
  }

  void _stopMerchantRefresh({required bool clearMerchant}) {
    _merchantRefreshGeneration++;
    _activeMerchantToken = null;
    _merchantRefreshTimer?.cancel();
    _merchantRefreshTimer = null;
    if (clearMerchant) _merchantStore.clear();
  }

  Future<void> _persist(PersistedSession session) async {
    _session = session;
    _merchantStore.replace(session.merchant);
    try {
      await _sessionStore.save(session);
    } catch (error) {
      _log('No se pudo guardar la sesión ($error).');
    }
  }

  Future<void> _clearStoredSession() async {
    try {
      await _sessionStore.clear();
    } catch (error) {
      _log('No se pudo borrar la sesión guardada ($error).');
    }
  }

  Future<void> _dropMemoryAndStorage() async {
    _session = null;
    _stopMerchantRefresh(clearMerchant: true);
    await _clearStoredSession();
  }

  Future<void> _forget(AuthState next) async {
    await _dropMemoryAndStorage();
    if (!isClosed) emit(next);
  }

  AuthSuccess _successFrom(PersistedSession session, {String? message}) {
    return AuthSuccess(
      user: session.user,
      message: message,
      mustChangePassword: session.mustChangePassword,
      merchant: session.merchant,
    );
  }

  Future<void> logout() async {
    await _forget(const AuthInitial());
    await _authRepository.logout();
  }

  /// Limpia un error de formulario. Si la sesión sigue guardada, la vuelve a
  /// mostrar; si no, deja la app sin sesión.
  void resetState() {
    final session = _session;
    if (session == null) {
      _stopMerchantRefresh(clearMerchant: true);
      emit(const AuthInitial());
      return;
    }
    _merchantStore.replace(session.merchant);
    emit(_successFrom(session));
  }

  @override
  Future<void> close() {
    _stopMerchantRefresh(clearMerchant: true);
    return super.close();
  }
}
