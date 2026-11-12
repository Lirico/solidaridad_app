import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../data/merchant_store.dart';
import '../../domain/auth_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final MerchantStore _merchantStore;
  final Duration _merchantRefreshInterval;
  final Duration _merchantRetryDelay;
  final int _merchantRefreshAttempts;
  final Future<void> Function(Duration) _retryWait;
  final Timer Function(Duration, void Function()) _schedule;
  final void Function(String) _log;
  int _merchantRefreshGeneration = 0;
  String? _activeMerchantToken;
  Timer? _merchantRefreshTimer;

  AuthCubit({
    required this._authRepository,
    MerchantStore? merchantStore,
    this._merchantRefreshInterval = const Duration(minutes: 15),
    this._merchantRetryDelay = const Duration(seconds: 1),
    int merchantRefreshAttempts = 3,
    Future<void> Function(Duration)? retryWait,
    Timer Function(Duration, void Function())? schedule,
    void Function(String)? log,
  }) : _merchantStore = merchantStore ?? MerchantStore(),
       _merchantRefreshAttempts = merchantRefreshAttempts < 1
           ? 1
           : merchantRefreshAttempts,
       _retryWait = retryWait ?? Future<void>.delayed,
       _schedule =
           schedule ?? ((duration, callback) => Timer(duration, callback)),
       _log = log ?? debugPrint,
       super(const AuthInitial());

  Merchant? get merchant => _merchantStore.current;

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _stopMerchantRefresh(clearMerchant: true);
    emit(const AuthLoading());

    final response = await _authRepository.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );

    if (response.isSuccess && response.user != null) {
      _merchantStore.replace(response.merchant);
      emit(
        AuthSuccess(
          user: response.user!,
          message: response.message,
          mustChangePassword: response.mustChangePassword,
          merchant: response.merchant,
        ),
      );
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
    _stopMerchantRefresh(clearMerchant: true);
    emit(const AuthLoading());

    final response = await _authRepository.register(
      name: name,
      email: email,
      password: password,
    );

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
    emit(const AuthLoading(loadingMessage: 'Cambiando contraseña...'));

    final response = await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      token: previous?.user?.token ?? '',
    );

    if (response.sessionExpired) {
      _stopMerchantRefresh(clearMerchant: true);
      emit(AuthSessionExpired(message: response.message));
      return;
    }

    if (response.isSuccess) {
      emit(
        AuthSuccess(
          user: previous?.user,
          message: response.message,
          merchant: _merchantStore.current,
        ),
      );
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
        _merchantStore.replace(refreshed);
        final current = state;
        if (current is AuthSuccess) {
          emit(
            AuthSuccess(
              user: current.user,
              message: current.message,
              mustChangePassword: current.mustChangePassword,
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
    final reason = lastLookup?.sessionExpired == true
        ? 'sesión no autorizada'
        : lastLookup?.unavailable == true
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

  Future<void> logout() async {
    _stopMerchantRefresh(clearMerchant: true);
    await _authRepository.logout();
    emit(const AuthInitial());
  }

  void resetState() {
    _stopMerchantRefresh(clearMerchant: true);
    emit(const AuthInitial());
  }

  @override
  Future<void> close() {
    _stopMerchantRefresh(clearMerchant: true);
    return super.close();
  }
}
