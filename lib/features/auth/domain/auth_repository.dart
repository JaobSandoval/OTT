import 'package:exel_ott/features/auth/domain/user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;
}

abstract class AuthRepository {
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  });

  Future<User> getCurrentUser({required String token});
}

