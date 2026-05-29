import 'package:dio/dio.dart';
import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/network/debug_dio.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/auth/domain/user.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository({required SessionStore sessionStore})
      : _dio = createDebugDio(
          baseOptions: BaseOptions(baseUrl: AppRuntimeEndpoints.instance.apiBaseUrl),
        );

  final Dio _dio;

  @override
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    TechnicalLogStore.instance.info(
      'AUTH',
      'POST /auth/login — campos enviados',
      fields: {
        'username': usernameOrEmail,
        'password': '***',
        'baseUrl': AppRuntimeEndpoints.instance.apiBaseUrl,
      },
    );
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
    TechnicalLogStore.instance.info(
      'AUTH',
      'POST /auth/login — respuesta',
      fields: {
        'access_token': token.isEmpty ? '(vacío)' : '${token.substring(0, token.length.clamp(0, 12))}…',
        'user.name': (u['name'] as String?) ?? '',
        'user.email': (u['email'] as String?) ?? '',
      },
    );
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

