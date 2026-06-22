import 'dart:convert';
import 'dart:developer' as dev;

import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/visual_scan/domain/image_scan_classification.dart';
import 'package:flutter/foundation.dart';

/// Cliente SOAP para ClasificarTipoImagenEscaneo en APIXLMovil.asmx.
class ApiXlMovilImageClassifyClient {
  ApiXlMovilImageClassifyClient({ApiXlMovilSoapClient? soapClient})
      : _soap = soapClient ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  static const _method = 'ClasificarTipoImagenEscaneo';
  static const _resultTag = 'ClasificarTipoImagenEscaneoResult';

  Future<ImageScanClassification> clasificar({
    required int idUsuario,
    required String password,
    required String imagenBase64,
    String contentType = 'image/jpeg',
  }) async {
    final bodyXml = [
      ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario),
      ApiXlMovilSoapClient.param('Password', password),
      ApiXlMovilSoapClient.param('imagenBase64', imagenBase64),
      ApiXlMovilSoapClient.param('contentType', contentType),
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

    final decoded = jsonDecode(jsonResult) as Map<String, dynamic>;
    if (kDebugMode) {
      dev.log(
        const JsonEncoder.withIndent('  ').convert(decoded),
        name: 'API.ClasificarTipoImagenEscaneo',
      );
      final debugOpenAi = decoded['debug_openai'];
      if (debugOpenAi != null) {
        dev.log(
          const JsonEncoder.withIndent('  ').convert(debugOpenAi),
          name: 'OpenAI.ClasificarTipoImagenEscaneo',
        );
      }
    }

    final status = (decoded['status'] as String?)?.toLowerCase();
    if (status == 'error') {
      throw Exception(
        decoded['mensaje']?.toString() ?? 'Error al clasificar la imagen.',
      );
    }

    return ImageScanClassification.fromJson(decoded);
  }
}
