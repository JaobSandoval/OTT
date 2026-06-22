import 'package:exel_ott/features/welcome/data/welcome_banners_api.dart';
import 'package:exel_ott/features/welcome/data/welcome_marcas_api.dart';
import 'package:exel_ott/features/welcome/domain/welcome_content.dart';

class WelcomeBannersRepository {
  WelcomeBannersRepository({
    WelcomeBannersApi? bannersApi,
    WelcomeMarcasApi? marcasApi,
  })  : _bannersApi = bannersApi ?? WelcomeBannersApi(),
        _marcasApi = marcasApi ?? WelcomeMarcasApi();

  final WelcomeBannersApi _bannersApi;
  final WelcomeMarcasApi _marcasApi;

  Future<WelcomeContent> loadPreLoginContent() async {
    final squaresFuture = _bannersApi.fetchBanners();
    final marcasFuture = _marcasApi.fetchMarcas();

    return WelcomeContent(
      squares: await squaresFuture,
      marcas: await marcasFuture,
    );
  }
}
