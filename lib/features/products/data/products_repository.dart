import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/products/data/apixlmovil_api.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';

class ProductsRepository {
  ProductsRepository({
    required SessionStore sessionStore,
    ApiXlMovilApi? api,
  })  : _sessionStore = sessionStore,
        _api = api ?? ApiXlMovilApi();

  final SessionStore _sessionStore;
  final ApiXlMovilApi _api;
  final Map<String, String?> _precioCache = {};
  final Set<String> _precioLoaded = {};

  void clearPrecioCache() {
    _precioCache.clear();
    _precioLoaded.clear();
  }

  String? getCachedPrecio(String idProducto) {
    if (!_precioLoaded.contains(idProducto)) return null;
    return _precioCache[idProducto];
  }

  bool hasCachedPrecio(String idProducto) =>
      _precioLoaded.contains(idProducto);

  Future<({int idUsuario, String password})> _credentials() async {
    await AppRuntimeEndpoints.instance.refreshRemoteConfig();

    final creds = await _sessionStore.readExelCredentials();
    if (creds == null) {
      throw Exception('Sesión incompleta. Vuelve a iniciar sesión.');
    }

    final ids = await _sessionStore.readExelSecurityIds();
    if (ids == null) {
      throw Exception('No se encontró el id de usuario. Inicia sesión de nuevo.');
    }

    final idUsuario = int.tryParse(ids.idUsuario);
    if (idUsuario == null || idUsuario <= 0) {
      throw Exception('Id de usuario inválido.');
    }

    return (idUsuario: idUsuario, password: creds.password);
  }

  Future<List<ProductCard>> search(
    String query, {
    ProductSearchFilters filters = const ProductSearchFilters(),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final creds = await _credentials();
    return _api.buscador(
      idUsuario: creds.idUsuario,
      password: creds.password,
      busqueda: trimmed,
      idCategoria: filters.idCategoria,
      idSubcategoria: filters.idSubcategoria,
      idMarca: filters.idMarca,
    );
  }

  Future<String?> fetchPrecio(String idProducto) async {
    if (_precioLoaded.contains(idProducto)) {
      return _precioCache[idProducto];
    }

    final creds = await _credentials();
    final precio = await _api.productoPrecio(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
    );
    _precioLoaded.add(idProducto);
    _precioCache[idProducto] = precio;
    return precio;
  }

  Future<ProductDetail> fetchDetail(String idProducto) async {
    final creds = await _credentials();
    final profile = await _sessionStore.readExelUserProfile();
    final idLocalidad = profile?.regions.split(',').first.trim();

    return _api.loadProductDetail(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
      idLocalidadUsuario:
          idLocalidad != null && idLocalidad.isNotEmpty ? idLocalidad : null,
    );
  }
}
