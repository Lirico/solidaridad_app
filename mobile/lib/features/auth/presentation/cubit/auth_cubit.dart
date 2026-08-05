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
    final previousUser = state is AuthSuccess
        ? (state as AuthSuccess).user
        : null;
    emit(const AuthLoading(loadingMessage: 'Cambiando contraseña...'));

    final response = await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (response.sessionExpired) {
      emit(AuthSessionExpired(message: response.message));
      return;
    }

    if (response.isSuccess) {
      emit(AuthSuccess(user: previousUser, message: response.message));
    } else {
      emit(AuthError(message: response.message));
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AuthInitial());
  }

  void resetState() {
    emit(const AuthInitial());
  }
}
