import 'dart:math';

import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/auth/domain/user.dart';

class AuthMockRepository implements AuthRepository {
  static const demoUser = User(
    name: 'JOSE LUIS SEGURA HERNANDEZ',
    email: 'demo@exel.com.mx',
    regions: 'CH,CJ,CN,GD,HE,LC,LG,MD,Mx...',
  );

  @override
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final normalized = usernameOrEmail.trim().toLowerCase();
    final ok = (normalized == 'demo@exel.com.mx' || normalized == 'demo@exel.com') &&
        password.trim() == 'demo';
    if (!ok) {
      throw Exception('Credenciales inválidas. Usa demo@exel.com.mx / demo');
    }
    final token = 'mock_${Random().nextInt(1 << 31)}';
    return AuthResult(token: token, user: demoUser);
  }

  @override
  Future<User> getCurrentUser({required String token}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return demoUser;
  }
}

