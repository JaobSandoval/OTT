import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/features/cart/data/cart_response_parser.dart';
import 'package:exel_ott/features/cart/domain/cart_item.dart';
import 'package:exel_ott/features/cart/domain/cart_operation_result.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';

/// Cliente SOAP de carrito para APIXLMovil.
class CartApi {
  CartApi({ApiXlMovilSoapClient? soap})
      : _soap = soap ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  Future<CartOperationResult> agregarProducto({
    required int idUsuario,
    required String password,
    required String idProducto,
    required int cantidad,
    required String idLocalidad,
  }) async {
    TechnicalLogStore.instance.info(
      'CART',
      'AgregarProducto SOAP',
      fields: {
        'id_producto': idProducto,
        'cantidad': '$cantidad',
        'id_localidad': idLocalidad,
      },
    );

    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}
${ApiXlMovilSoapClient.param('cantidad', cantidad.toString())}
${ApiXlMovilSoapClient.param('id_localidad', idLocalidad)}''';

    final xml = await _soap.invoke(
      methodName: 'AgregarProducto',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final payload =
        ApiXlMovilSoapClient.extractSoapResult(xml, 'AgregarProductoResult');
    return CartResponseParser.parseOperation(payload);
  }

  Future<List<CartItem>> consultaCarrito({
    required int idUsuario,
    required String password,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}''';

    final xml = await _soap.invoke(
      methodName: 'ConsultaCarrito',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final payload =
        ApiXlMovilSoapClient.extractSoapResult(xml, 'ConsultaCarritoResult');
    return CartResponseParser.parseConsultaCarrito(payload);
  }

  Future<CartOperationResult> ajustarCantidad({
    required int idUsuario,
    required String password,
    required String idProducto,
    required String idLocalidad,
    required int delta,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}
${ApiXlMovilSoapClient.param('id_localidad', idLocalidad)}
${ApiXlMovilSoapClient.param('delta', delta.toString())}''';

    final xml = await _soap.invoke(
      methodName: 'AjustarCantidadProducto',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final payload = ApiXlMovilSoapClient.extractSoapResult(
      xml,
      'AjustarCantidadProductoResult',
    );
    return CartResponseParser.parseOperation(payload);
  }

  Future<CartOperationResult> establecerCantidad({
    required int idUsuario,
    required String password,
    required String idProducto,
    required String idLocalidad,
    required int cantidad,
  }) async {
    final body = '''
${ApiXlMovilSoapClient.paramInt('id_usuario', idUsuario)}
${ApiXlMovilSoapClient.param('Password', password)}
${ApiXlMovilSoapClient.param('id_producto', idProducto)}
${ApiXlMovilSoapClient.param('id_localidad', idLocalidad)}
${ApiXlMovilSoapClient.param('cantidad', cantidad.toString())}''';

    final xml = await _soap.invoke(
      methodName: 'EstablecerCantidadProducto',
      idUsuario: idUsuario,
      password: password,
      bodyXml: body,
    );

    final payload = ApiXlMovilSoapClient.extractSoapResult(
      xml,
      'EstablecerCantidadProductoResult',
    );
    return CartResponseParser.parseOperation(payload);
  }
}
