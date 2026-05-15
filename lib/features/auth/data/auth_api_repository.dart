import 'package:dio/dio.dart';
import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/auth/domain/user.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository({required SessionStore sessionStore})
      : _dio = Dio(
          BaseOptions(baseUrl: AppRuntimeEndpoints.instance.apiBaseUrl),
        );

  final Dio _dio;

  @override
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'username': usernameOrEmail,
        'password': password,
      },
    );

    final data = res.data ?? const <String, dynamic>{};
    final token = (data['access_token'] as String?) ?? '';
    final u = (data['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AuthResult(
      token: token,
      user: User(
        name: (u['name'] as String?) ?? '',
        email: (u['email'] as String?) ?? '',
        regions: (u['regions'] as String?) ?? '',
      ),
    );
  }

  @override
  Future<User> getCurrentUser({required String token}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final u = res.data ?? const <String, dynamic>{};
    return User(
      name: (u['name'] as String?) ?? '',
      email: (u['email'] as String?) ?? '',
      regions: (u['regions'] as String?) ?? '',
    );
  }
}

