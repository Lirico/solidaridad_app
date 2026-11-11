import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({required this._authRepository}) : super(const AuthInitial());

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    emit(const AuthLoading());

    final response = await _authRepository.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );

    if (response.isSuccess && response.user != null) {
      emit(
        AuthSuccess(
          user: response.user!,
          message: response.message,
          mustChangePassword: response.mustChangePassword,
          merchant: response.merchant,
        ),
      );
    } else {
      emit(AuthError(message: response.message));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
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
      emit(AuthSessionExpired(message: response.message));
      return;
    }

    if (response.isSuccess) {
      emit(
        AuthSuccess(
          user: previous?.user,
          message: response.message,
          merchant: previous?.merchant,
        ),
      );
    } else {
      emit(AuthError(message: response.message));
    }
  }

  /// Pide el comercio vigente. Si la red falla, conserva el del login.
  /// Si la cuenta no tiene comercio, lo quita de la sesión.
  Future<Merchant?> refreshMerchant() async {
    final current = state;
    if (current is! AuthSuccess || current.user == null) return null;

    final lookup = await _authRepository.fetchCurrentMerchant(
      token: current.user!.token,
    );
    if (lookup.unavailable) return current.merchant;
    if (lookup.sessionExpired) {
      emit(
        const AuthSessionExpired(
          message: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
        ),
      );
      return null;
    }

    emit(
      AuthSuccess(
        user: current.user,
        message: current.message,
        mustChangePassword: current.mustChangePassword,
        merchant: lookup.merchant,
      ),
    );
    return lookup.merchant;
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AuthInitial());
  }

  void resetState() {
    emit(const AuthInitial());
  }
}
