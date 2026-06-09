import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_extraction_parser.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_line.dart';

/// Cliente SOAP para ExtraerLineasCotizacionImagen en APIXLMovil.asmx.
class ApiXlMovilQuoteClient {
  ApiXlMovilQuoteClient({ApiXlMovilSoapClient? soapClient})
      : _soap = soapClient ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  static const _method = 'ExtraerLineasCotizacionImagen';
  static const _resultTag = 'ExtraerLineasCotizacionImagenResult';

  Future<QuoteExtractionResult> extraerLineasCotizacionImagen({
    required int idUsuario,
    required String password,
    required String imagenBase64,
    String contentType = 'image/jpeg',
  }) async {
    TechnicalLogStore.instance.info(
      'QUOTE',
      '$_method — solicitud SOAP',
      fields: {
        'id_usuario': '$idUsuario',
        'contentType': contentType,
        'imageBase64Length': '${imagenBase64.length}',
      },
    );

    // Construir los parámetros XML del body SOAP.
    // Base64 no contiene caracteres especiales XML (<>&"'), pero usamos
    // ApiXlMovilSoapClient.param para uniformidad.
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

    // extractSoapResult lanza Exception si hay soap:Fault.
    final jsonResult = ApiXlMovilSoapClient.extractSoapResult(
      soapResponse,
      _resultTag,
    );

    final result = QuoteExtractionParser.parse(jsonResult);

    TechnicalLogStore.instance.info(
      'QUOTE',
      '$_method — líneas detectadas',
      fields: {'total': '${result.lineas.length}'},
    );

    return result;
  }
}
