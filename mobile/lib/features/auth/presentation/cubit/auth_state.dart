import '../../domain/auth_model.dart';

export '../../domain/auth_model.dart' show Merchant;

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
  final Merchant? merchant;

  const AuthSuccess({
    super.user,
    super.message,
    this.mustChangePassword = false,
    this.merchant,
  });
}

class AuthError extends AuthState {
  const AuthError({required super.message});
}

/// Emitted when the API returns 401 (token expired/invalid).
class AuthSessionExpired extends AuthState {
  const AuthSessionExpired({super.message});
}
