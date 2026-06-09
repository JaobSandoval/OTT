import 'dart:convert';

import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';

/// Cliente SOAP para PermisoEscaneoImagenes en APIXLMovil.asmx.
class ApiXlMovilImageScanPermissionClient {
  ApiXlMovilImageScanPermissionClient({ApiXlMovilSoapClient? soapClient})
      : _soap = soapClient ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  static const _method = 'PermisoEscaneoImagenes';
  static const _resultTag = 'PermisoEscaneoImagenesResult';

  Future<bool> consultar({
    required int idUsuario,
    required String password,
  }) async {
    final bodyXml = [
      ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario),
      ApiXlMovilSoapClient.param('Password', password),
    ].join('\n');

    final soapResponse = await _soap.invoke(
      methodName: _method,
      idUsuario: idUsuario,
      password: password,
      bodyXml: bodyXml,
    );

    final jsonResult = ApiXlMovilSoapClient.extractSoapResult(
      soapResponse,
      _resultTag,
    );

    final decoded = jsonDecode(jsonResult);
    if (decoded is List && decoded.isNotEmpty) {
      final row = decoded.first;
      if (row is Map<String, dynamic>) {
        return _parseEnabled(row['HabilitarEscaneoDeImagenesEnAppXLStore']);
      }
    }

    if (decoded is Map<String, dynamic>) {
      final enabled = decoded['habilitarEscaneoDeImagenesEnAppXLStore']
          ?? decoded['HabilitarEscaneoDeImagenesEnAppXLStore'];
      if (enabled != null) return _parseEnabled(enabled);
      if (decoded['ok'] == false) {
        throw Exception(
          decoded['mensaje']?.toString() ?? 'No se pudo consultar el permiso.',
        );
      }
    }

    return false;
  }

  bool _parseEnabled(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si' || text == 'sí';
  }
}
