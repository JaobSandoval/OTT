import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/network/debug_dio.dart';
import 'package:exel_ott/core/security/bff_request_token_manager.dart';
import 'package:xml/xml.dart';

/// Cliente SOAP genérico para APIXLMovil.asmx.
class ApiXlMovilSoapClient {
  ApiXlMovilSoapClient({Dio? dio}) : _dio = dio ?? createDebugDio();

  static const tempUri = 'http://tempuri.org/';
  static const _tokenRetryDelay = Duration(milliseconds: 1500);

  final Dio _dio;

  String get soapUrl => AppRuntimeEndpoints.instance.apiXlMovilAsmxUrl;

  Future<String> invoke({
    required String methodName,
    required int idUsuario,
    required String password,
    required String bodyXml,
  }) async {
    final userId = idUsuario.toString();
    final envelope = _buildEnvelope(methodName, bodyXml);
    final tokenManager = BffRequestTokenManager.instance;

    var res = await _post(
      methodName: methodName,
      envelope: envelope,
      token: tokenManager.getToken(userId),
    );

    if (res.statusCode == 403 || res.statusCode == 401) {
      await Future<void>.delayed(_tokenRetryDelay);
      res = await _post(
        methodName: methodName,
        envelope: envelope,
        token: tokenManager.refreshToken(userId),
      );
    }

    if (res.statusCode == 403 || res.statusCode == 401) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        message: 'Acceso denegado o token expirado',
      );
    }

    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception('Error del servicio (HTTP ${res.statusCode}).');
    }

    return res.data ?? '';
  }

  String _buildEnvelope(String methodName, String bodyXml) =>
      '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <$methodName xmlns="$tempUri">
$bodyXml
    </$methodName>
  </soap:Body>
</soap:Envelope>''';

  Future<Response<String>> _post({
    required String methodName,
    required String envelope,
    required String token,
  }) {
    return _dio.post<String>(
      soapUrl,
      data: envelope,
      options: Options(
        contentType: 'text/xml; charset=utf-8',
        responseType: ResponseType.plain,
        headers: {
          'SOAPAction': 'http://tempuri.org/$methodName',
          'X-Request-Token': token,
        },
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  static String extractSoapResult(String xml, String resultTag) {
    final trimmed = xml.trim();
    if (trimmed.contains('soap:Fault') || trimmed.contains(':Fault>')) {
      final doc = XmlDocument.parse(trimmed);
      final fault = _textIn(doc.rootElement, 'faultstring');
      throw Exception(fault.isEmpty ? 'Error en el servicio.' : fault);
    }

    final doc = XmlDocument.parse(trimmed);
    final node = _firstElement(doc.rootElement, resultTag);
    if (node == null) {
      throw Exception('Respuesta SOAP sin $resultTag.');
    }
    return node.innerText.trim();
  }

  static String param(String tag, String value) =>
      '      <$tag>${escapeXml(value)}</$tag>';

  static String paramInt(String tag, int value) => '      <$tag>$value</$tag>';

  static String escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static XmlElement? _firstElement(XmlElement parent, String localName) {
    for (final node in parent.descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) return node;
    }
    return null;
  }

  static String _textIn(XmlElement parent, String localName) {
    final node = _firstElement(parent, localName);
    return node?.innerText.trim() ?? '';
  }
}
