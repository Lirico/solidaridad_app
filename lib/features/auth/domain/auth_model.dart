class User {
  final String name;
  final String email;
  final String token;

  const User({required this.name, required this.email, required this.token});
}

class AuthResponse {
  final bool isSuccess;
  final User? user;
  final String message;

  const AuthResponse({
    required this.isSuccess,
    this.user,
    required this.message,
  });
}
