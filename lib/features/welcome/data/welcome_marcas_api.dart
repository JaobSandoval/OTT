import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/welcome/data/welcome_marcas_parser.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';

class WelcomeMarcasApi {
  WelcomeMarcasApi({ApiXlMovilSoapClient? soap})
      : _soap = soap ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  Future<List<WelcomeMarca>> fetchMarcas() async {
    TechnicalLogStore.instance.info(
      'WELCOME',
      'MarcasPreLoginPublico SOAP — solicitud',
    );

    final xml = await _soap.invoke(
      methodName: 'MarcasPreLoginPublico',
      idUsuario: 0,
      password: '',
      bodyXml: '',
    );

    final marcas = WelcomeMarcasParser.parse(xml);
    TechnicalLogStore.instance.info(
      'WELCOME',
      'MarcasPreLoginPublico SOAP — respuesta',
      fields: {'marcas': '${marcas.length}'},
    );
    return marcas;
  }
}
