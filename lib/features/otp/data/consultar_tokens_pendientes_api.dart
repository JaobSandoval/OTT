import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_response_parser.dart';
import 'package:exel_ott/features/otp/data/consultar_tokens_pendientes_response_parser.dart';

/// Llama `ConsultarToken` vía SOAP 1.1 (mismo WS que login).
class ConsultarTokensPendientesApi {
  ConsultarTokensPendientesApi({Dio? dio}) : _dio = dio ?? Dio();

  static const _operation = 'ConsultarToken';
  static const _soapAction = 'http://tempuri.org/$_operation';
  static const _tempUri = 'http://tempuri.org/';

  final Dio _dio;

  Future<List<PendingToken>> consultar({
    required String idCliente,
    required String idUsuario,
  }) async {
    final envelope = _buildEnvelope(
      idCliente: idCliente,
      idUsuario: idUsuario,
    );

    try {
      final res = await _dio.post<String>(
        AppConfig.loginRegistrarTokenSoapUrl,
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
        throw Exception(_friendlyHttpError(res.statusCode!, body));
      }

      return ConsultarTokensPendientesResponseParser.parse(body);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is String && data.trim().isNotEmpty) {
        throw Exception(_friendlyHttpError(e.response?.statusCode ?? 0, data));
      }
      throw Exception('No se pudo consultar el código de validación.');
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
    return 'No se pudo obtener el código. Intenta más tarde.';
  }

  String _buildEnvelope({
    required String idCliente,
    required String idUsuario,
  }) {
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <$_operation xmlns="$_tempUri">
      <IdCliente>${_escapeXml(idCliente)}</IdCliente>
      <IdUsuario>${_escapeXml(idUsuario)}</IdUsuario>
    </$_operation>
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
