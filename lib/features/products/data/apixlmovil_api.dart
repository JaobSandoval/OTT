import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/features/products/data/apixlmovil_buscador_response_parser.dart';
import 'package:exel_ott/features/products/data/apixlmovil_product_parsers.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';

/// Cliente SOAP para APIXLMovil (mismo estilo que la página Invocar / Postman SOAP).
class ApiXlMovilApi {
  ApiXlMovilApi({ApiXlMovilSoapClient? soap})
      : _soap = soap ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  Future<List<ProductCard>> buscador({
    required int idUsuario,
    required String password,
    required String busqueda,
    String idCategoria = '',
    String idSubcategoria = '',
    String idMarca = '',
  }) async {
    TechnicalLogStore.instance.info(
      'PRODUCTS',
      'Buscador SOAP — solicitud',
      fields: {'busqueda': busqueda, 'id_usuario': '$idUsuario'},
    );

    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('busqueda', busqueda)}
${ApiXlMovilSoapClient.param('id_categoria', idCategoria)}
${ApiXlMovilSoapClient.param('id_subcategoria', idSubcategoria)}
${ApiXlMovilSoapClient.param('id_marca', idMarca)}''';

    final xml = await _soap.invoke(
      methodName: 'Buscador',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final list = ApiXlMovilBuscadorResponseParser.parse(xml);
    TechnicalLogStore.instance.info(
      'PRODUCTS',
      'Buscador SOAP — respuesta',
      fields: {'total': '${list.length}'},
    );
    return list;
  }

  Future<String?> productoPrecio({
    required int idUsuario,
    required String password,
    required String idProducto,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}''';

    final xml = await _soap.invoke(
      methodName: 'ProductoPrecio',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final payload =
        ApiXlMovilSoapClient.extractSoapResult(xml, 'ProductoPrecioResult');
    return ApiXlMovilProductParsers.parsePrecio(payload);
  }

  Future<String> productoPrecioExistencia({
    required int idUsuario,
    required String password,
    required String idProducto,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}''';

    final xml = await _soap.invoke(
      methodName: 'ProductoPrecioExistencia',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    return ApiXlMovilSoapClient.extractSoapResult(
      xml,
      'ProductoPrecioExistenciaResult',
    );
  }

  Future<String> fichaTecnica({
    required int idUsuario,
    required String password,
    required String idProducto,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}''';

    final xml = await _soap.invoke(
      methodName: 'FichaTecnica',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    return ApiXlMovilSoapClient.extractSoapResult(xml, 'FichaTecnicaResult');
  }

  Future<ProductDetail> loadProductDetail({
    required int idUsuario,
    required String password,
    required String idProducto,
    String? idLocalidadUsuario,
  }) async {
    final results = await Future.wait([
      productoPrecioExistencia(
        idUsuario: idUsuario,
        password: password,
        idProducto: idProducto,
      ),
      fichaTecnica(
        idUsuario: idUsuario,
        password: password,
        idProducto: idProducto,
      ),
    ]);

    return ApiXlMovilProductParsers.parseDetail(
      idProducto: idProducto,
      existenciaPayload: results[0],
      fichaPayload: results[1],
      idLocalidadUsuario: idLocalidadUsuario,
    );
  }
}
