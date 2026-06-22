import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/welcome/data/welcome_banners_parser.dart';
import 'package:exel_ott/features/welcome/domain/welcome_banner.dart';

class WelcomeBannersApi {
  WelcomeBannersApi({ApiXlMovilSoapClient? soap})
      : _soap = soap ?? ApiXlMovilSoapClient();

  final ApiXlMovilSoapClient _soap;

  Future<List<WelcomeBanner>> fetchBanners() async {
    TechnicalLogStore.instance.info(
      'WELCOME',
      'BannersPreLoginPublico SOAP — solicitud',
    );

    final xml = await _soap.invoke(
      methodName: 'BannersPreLoginPublico',
      idUsuario: 0,
      password: '',
      bodyXml: '',
    );

    final banners = WelcomeBannersParser.parseBanners(xml);
    TechnicalLogStore.instance.info(
      'WELCOME',
      'BannersPreLoginPublico SOAP — respuesta',
      fields: {'squares': '${banners.length}'},
    );
    return banners;
  }
}
