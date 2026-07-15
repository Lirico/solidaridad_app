import '../../domain/auth_model.dart';

abstract class AuthState {
  final User? user;
  final String? message;

  const AuthState({this.user, this.message});
}

class AuthInitial extends AuthState {
  const AuthInitial() : super();
}

class AuthLoading extends AuthState {
  final String? loadingMessage;

  const AuthLoading({this.loadingMessage}) : super();
}

class AuthSuccess extends AuthState {
  final bool mustChangePassword;

  const AuthSuccess({
    super.user,
    super.message,
    this.mustChangePassword = false,
  });
}

class AuthError extends AuthState {
  const AuthError({required super.message});
}
