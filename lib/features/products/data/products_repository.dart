import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/products/data/apixlmovil_api.dart';
import 'package:exel_ott/features/products/data/apixlmovil_product_parsers.dart';
import 'package:exel_ott/features/products/data/product_card_extras_batcher.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';

class ProductsRepository {
  ProductsRepository({
    required SessionStore sessionStore,
    ApiXlMovilApi? api,
    ProductCardExtrasPrefetcher? cardExtrasPrefetcher,
  })  : _sessionStore = sessionStore,
        _api = api ?? ApiXlMovilApi() {
    _cardExtrasPrefetcher =
        cardExtrasPrefetcher ?? ProductCardExtrasPrefetcher(api: _api);
  }

  final SessionStore _sessionStore;
  final ApiXlMovilApi _api;
  late final ProductCardExtrasPrefetcher _cardExtrasPrefetcher;
  final Map<String, String?> _precioCache = {};
  final Set<String> _precioLoaded = {};
  final Map<String, ({String sucursal, String nacional})> _existenciaCache = {};
  final Set<String> _existenciaLoaded = {};
  final Map<String, String?> _imageUrlCache = {};

  void clearPrecioCache() {
    _precioCache.clear();
    _precioLoaded.clear();
    _existenciaCache.clear();
    _existenciaLoaded.clear();
    _imageUrlCache.clear();
    _cardExtrasPrefetcher.reset();
  }

  Future<void> prepareProductExtrasList(List<ProductCard> products) {
    final ids = products.map((p) => p.idProducto).where((id) => id.isNotEmpty);
    return _cardExtrasPrefetcher.prepareList(
      ids.toList(),
      fetchBatch: _fetchAndStoreBatch,
      isCached: _existenciaLoaded.contains,
    );
  }

  void onProductListIndexVisible(int index) {
    _cardExtrasPrefetcher.onItemVisible(index);
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

  Future<({String? idSucursal, String? sucursalNombre})> _readSucursal() async {
    final sucursal = await _sessionStore.readExelSucursal();
    return (
      idSucursal: sucursal?.idSucursal,
      sucursalNombre: sucursal?.sucursalNombre,
    );
  }

  Future<List<ProductCard>> searchPublic(
    String query, {
    ProductSearchFilters filters = const ProductSearchFilters(),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty && !filters.hasAny) return const [];

    await AppRuntimeEndpoints.instance.refreshRemoteConfig();
    return _api.buscadorPublico(
      busqueda: trimmed.isEmpty ? '%' : trimmed,
      idCategoria: filters.idCategoria,
      idSubcategoria: filters.idSubcategoria,
      idMarca: filters.idMarca,
    );
  }

  Future<ProductDetail> fetchPublicDetail(
    String idProducto, {
    ProductCard? card,
  }) async {
    await AppRuntimeEndpoints.instance.refreshRemoteConfig();

    var resolvedCard = card;
    if (resolvedCard == null || resolvedCard.descripcion.trim().isEmpty) {
      resolvedCard = await _lookupPublicCard(
        idProducto,
        fallback: resolvedCard,
      );
    }

    return _api.loadPublicProductDetail(
      idProducto: idProducto,
      card: resolvedCard,
    );
  }

  Future<ProductCard?> _lookupPublicCard(
    String idProducto, {
    ProductCard? fallback,
  }) async {
    final id = idProducto.trim();
    if (id.isEmpty) return fallback;

    try {
      final results = await _api.buscadorPublico(busqueda: id);
      for (final product in results) {
        if (product.idProducto == id) return product;
      }
      if (results.length == 1) return results.first;
    } on Object {
      // Si falla la búsqueda, el detalle sigue con ficha técnica.
    }
    return fallback;
  }

  Future<List<ProductCard>> search(
    String query, {
    ProductSearchFilters filters = const ProductSearchFilters(),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty && !filters.hasAny) return const [];

    final creds = await _credentials();
    return _api.buscador(
      idUsuario: creds.idUsuario,
      password: creds.password,
      busqueda: trimmed.isEmpty ? '%' : trimmed,
      idCategoria: filters.idCategoria,
      idSubcategoria: filters.idSubcategoria,
      idMarca: filters.idMarca,
    );
  }

  Future<List<ProductCard>> fetchProductosNuevos() async {
    final creds = await _credentials();
    return _api.listadoProductosNuevos(
      idUsuario: creds.idUsuario,
      password: creds.password,
    );
  }

  Future<String> userSucursalLabel() async {
    final sucursal = await _sessionStore.readExelSucursal();
    final name = sucursal?.sucursalNombre.trim() ?? '';
    return name.isNotEmpty ? name.toUpperCase() : 'SUCURSAL';
  }

  bool hasCachedExistencia(String idProducto) =>
      _existenciaLoaded.contains(idProducto);

  String? getCachedImageUrl(String idProducto) {
    if (!_existenciaLoaded.contains(idProducto)) return null;
    return _imageUrlCache[idProducto];
  }

  ({String sucursal, String nacional})? getCachedExistencia(String idProducto) {
    if (!_existenciaLoaded.contains(idProducto)) return null;
    return _existenciaCache[idProducto];
  }

  Future<({
    String sucursal,
    String nacional,
    String? precio,
    String? imageUrl,
  })> fetchExistencia(
    String idProducto, {
    int? listIndex,
  }) async {
    if (_existenciaLoaded.contains(idProducto)) {
      final cached = _existenciaCache[idProducto]!;
      return (
        sucursal: cached.sucursal,
        nacional: cached.nacional,
        precio: getCachedPrecio(idProducto),
        imageUrl: _imageUrlCache[idProducto],
      );
    }

    await _cardExtrasPrefetcher.waitForProduct(
      idProducto,
      listIndex: listIndex,
    );

    if (_existenciaLoaded.contains(idProducto)) {
      final cached = _existenciaCache[idProducto]!;
      return (
        sucursal: cached.sucursal,
        nacional: cached.nacional,
        precio: getCachedPrecio(idProducto),
        imageUrl: _imageUrlCache[idProducto],
      );
    }

    final summary = await _cardExtrasPrefetcher.fetchSingle(
      idProducto: idProducto,
      credentials: _credentials,
      readSucursal: _readSucursal,
    );
    _storeCardExtras(idProducto, summary);
    return summary;
  }

  Future<void> _fetchAndStoreBatch(List<String> ids) async {
    if (ids.isEmpty) return;

    final creds = await _credentials();
    final sucursal = await _readSucursal();
    final payload = await _api.productoPrecioExistencia(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: ids.join(','),
    );
    final parsed = ApiXlMovilProductParsers.parseExistenciaSummaryBatch(
      payload,
      requestedIds: ids,
      idLocalidadUsuario: sucursal.idSucursal,
      sucursalNombreUsuario: sucursal.sucursalNombre,
    );
    for (final id in ids) {
      if (_existenciaLoaded.contains(id)) continue;
      _storeCardExtras(id, parsed[id]!);
    }
  }

  void _storeCardExtras(String idProducto, ProductCardExtras summary) {
    _existenciaLoaded.add(idProducto);
    _existenciaCache[idProducto] = (
      sucursal: summary.sucursal,
      nacional: summary.nacional,
    );
    _precioLoaded.add(idProducto);
    _precioCache[idProducto] = summary.precio;
    _imageUrlCache[idProducto] = summary.imageUrl;
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
    final sucursal = await _sessionStore.readExelSucursal();
    final idLocalidad = sucursal?.idSucursal;

    return _api.loadProductDetail(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
      idLocalidadUsuario:
          idLocalidad != null && idLocalidad.isNotEmpty ? idLocalidad : null,
    );
  }
}
