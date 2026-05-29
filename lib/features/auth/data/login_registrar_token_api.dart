import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/device/device_registration_info.dart';
import 'package:exel_ott/core/network/debug_dio.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_response_parser.dart';

/// Resultado de `LoginRegistrarToken` (`clsResultadoLoginMovil`).
class LoginRegistrarTokenResult {
  const LoginRegistrarTokenResult({required this.profile});

  final Map<String, dynamic> profile;
}

/// Llama `LoginRegistrarToken` vía SOAP 1.1 (este WS no expone JSON ScriptService).
class LoginRegistrarTokenApi {
  LoginRegistrarTokenApi({Dio? dio}) : _dio = dio ?? createDebugDio();

  static const _soapAction = 'http://tempuri.org/LoginRegistrarToken';
  static const _tempUri = 'http://tempuri.org/';

  final Dio _dio;

  Future<LoginRegistrarTokenResult> login({
    required String usuario,
    required String password,
    required String tokenFirebase,
    DeviceRegistrationInfo? device,
  }) async {
    final info = device ?? await DeviceRegistrationInfo.collect();
    TechnicalLogStore.instance.info(
      'AUTH',
      'LoginRegistrarToken — campos enviados',
      fields: {
        'url': AppRuntimeEndpoints.instance.loginRegistrarTokenSoapUrl,
        'IdAplicacion': AppConfig.exelIdAplicacion,
        'Usuario': usuario,
        'Password': '***',
        'TokenFirebase': tokenFirebase.isEmpty ? '(vacío)' : tokenFirebase,
        'TokenFirebaseLength': '${tokenFirebase.length}',
        'Plataforma': info.plataforma,
        'Modelo': info.modelo,
        'VersionSO': info.versionSo,
        'AppVersion': info.appVersion,
      },
    );
    final envelope = _buildEnvelope(
      idAplicacion: AppConfig.exelIdAplicacion,
      usuario: usuario,
      password: password,
      tokenFirebase: tokenFirebase,
      plataforma: info.plataforma,
      modelo: info.modelo,
      versionSo: info.versionSo,
      appVersion: info.appVersion,
    );

    try {
      final res = await _dio.post<String>(
        AppRuntimeEndpoints.instance.loginRegistrarTokenSoapUrl,
        data: envelope,
        options: Options(
          contentType: 'text/xml; charset=utf-8',
          responseType: ResponseType.plain,
          headers: {'SOAPAction': _soapAction},
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final body = res.data ?? '';
      if (res.statusCode != null && res.statusCode! >= 400) {
        TechnicalLogStore.instance.error(
          'AUTH',
          'LoginRegistrarToken — HTTP ${res.statusCode}',
          statusCode: res.statusCode,
          body: body,
          error: _friendlyHttpError(res.statusCode!, body),
        );
        throw Exception(_friendlyHttpError(res.statusCode!, body));
      }

      final profile = LoginRegistrarTokenResponseParser.parse(body);
      TechnicalLogStore.instance.info(
        'AUTH',
        'LoginRegistrarToken — respuesta parseada',
        fields: {
          for (final e in profile.entries)
            if (e.value != null && e.value.toString().isNotEmpty)
              e.key: e.value.toString(),
        },
        body: body,
      );
      return LoginRegistrarTokenResult(profile: profile);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is String && data.trim().isNotEmpty) {
        TechnicalLogStore.instance.error(
          'AUTH',
          'LoginRegistrarToken — DioException',
          statusCode: e.response?.statusCode,
          body: data,
          error: '${e.type}: ${e.message}',
        );
        throw Exception(_friendlyHttpError(e.response?.statusCode ?? 0, data));
      }
      TechnicalLogStore.instance.error(
        'AUTH',
        'LoginRegistrarToken — sin conexión',
        error: '${e.type}: ${e.message}',
      );
      throw Exception('No se pudo conectar con el servidor de login.');
    } on Exception catch (e) {
      TechnicalLogStore.instance.error(
        'AUTH',
        'LoginRegistrarToken — error de parseo/negocio',
        error: e.toString(),
      );
      rethrow;
    }
  }

  String _friendlyHttpError(int status, String body) {
    if (body.contains('faultstring')) {
      try {
        final fault = LoginRegistrarTokenResponseParser.parseSoapFault(body);
        if (fault.isNotEmpty) return fault;
      } on Object {
        // ignore
      }
    }
    return 'El servicio no está disponible. Intenta más tarde.';
  }

  String _buildEnvelope({
    required String idAplicacion,
    required String usuario,
    required String password,
    required String tokenFirebase,
    required String plataforma,
    required String modelo,
    required String versionSo,
    required String appVersion,
  }) {
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <LoginRegistrarToken xmlns="$_tempUri">
      <IdAplicacion>${_escapeXml(idAplicacion)}</IdAplicacion>
      <Usuario>${_escapeXml(usuario)}</Usuario>
      <Password>${_escapeXml(password)}</Password>
      <TokenFirebase>${_escapeXml(tokenFirebase)}</TokenFirebase>
      <Plataforma>${_escapeXml(plataforma)}</Plataforma>
      <Modelo>${_escapeXml(modelo)}</Modelo>
      <VersionSO>${_escapeXml(versionSo)}</VersionSO>
      <AppVersion>${_escapeXml(appVersion)}</AppVersion>
    </LoginRegistrarToken>
  </soap:Body>
</soap:Envelope>''';
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
