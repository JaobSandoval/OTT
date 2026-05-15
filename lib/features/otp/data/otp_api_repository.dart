import 'package:dio/dio.dart';
import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';

class OtpApiRepository implements OtpRepository {
  OtpApiRepository({required SessionStore sessionStore})
      : _sessionStore = sessionStore,
        _dio = Dio(
          BaseOptions(baseUrl: AppRuntimeEndpoints.instance.apiBaseUrl),
        );

  final SessionStore _sessionStore;
  final Dio _dio;

  @override
  Future<OtpCode?> fetchCurrent() async {
    final token = await _sessionStore.readToken();
    if (token == null) return null;

    final res = await _dio.get<Map<String, dynamic>>(
      '/otp/current',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final data = res.data;
    if (data == null) return null;
    final code = (data['code'] as String?) ?? '';
    final expiresAtRaw = (data['expires_at'] as String?) ?? '';
    if (code.isEmpty || expiresAtRaw.isEmpty) return null;
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) return null;

    return OtpCode(code: code, expiresAt: expiresAt);
  }

  @override
  Future<OtpCode> rotateMock() {
    throw UnsupportedError('rotateMock no aplica en API');
  }
}

