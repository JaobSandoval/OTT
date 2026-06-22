import 'dart:convert';

import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';

/// Cliente SOAP para IdentificarProductoPorFoto en APIXLMovil.asmx.
class ApiXlMovilProductPhotoClient {
  ApiXlMovilProductPhotoClient({ApiXlMovilSoapClient? soapClient})
      : _soap = soapClient ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  static const _method = 'IdentificarProductoPorFoto';
  static const _resultTag = 'IdentificarProductoPorFotoResult';

  /// [images] lista de 1-3 entradas {base64, contentType}.
  /// La imagen en índice 0 es obligatoria (frontal/principal).
  Future<PhotoIdentificationResponse> identificar({
    required int idUsuario,
    required String password,
    required List<({String base64, String contentType})> images,
  }) async {
    assert(images.isNotEmpty, 'Se requiere al menos una imagen.');

    // Completar hasta 3 slots (vacíos si no se proporcionaron)
    String b1 = '', ct1 = 'image/jpeg';
    String b2 = '', ct2 = 'image/jpeg';
    String b3 = '', ct3 = 'image/jpeg';

    if (images.isNotEmpty) { b1 = images[0].base64; ct1 = images[0].contentType; }
    if (images.length > 1) { b2 = images[1].base64; ct2 = images[1].contentType; }
    if (images.length > 2) { b3 = images[2].base64; ct3 = images[2].contentType; }

    final bodyXml = [
      ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario),
      ApiXlMovilSoapClient.param('Password', password),
      ApiXlMovilSoapClient.param('imagenBase64_1', b1),
      ApiXlMovilSoapClient.param('contentType1', ct1),
      ApiXlMovilSoapClient.param('imagenBase64_2', b2),
      ApiXlMovilSoapClient.param('contentType2', ct2),
      ApiXlMovilSoapClient.param('imagenBase64_3', b3),
      ApiXlMovilSoapClient.param('contentType3', ct3),
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

    final status = (decoded['status'] as String?)?.toLowerCase();
    if (status == 'error') {
      throw Exception(decoded['mensaje']?.toString() ?? 'Error al identificar el producto.');
    }

    return PhotoIdentificationResponse.fromJson(decoded);
  }
}
