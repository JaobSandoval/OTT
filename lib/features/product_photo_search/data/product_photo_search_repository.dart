import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/product_photo_search/data/apixlmovil_product_photo_client.dart';
import 'package:exel_ott/features/product_photo_search/domain/detected_product_match.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_image_compressor.dart';

class ProductPhotoSearchRepository {
  ProductPhotoSearchRepository({
    required SessionStore sessionStore,
    required ProductsRepository productsRepository,
    required CartRepository cartRepository,
    ApiXlMovilProductPhotoClient? photoClient,
  })  : _sessionStore = sessionStore,
        _productsRepository = productsRepository,
        _cartRepository = cartRepository,
        _photoClient = photoClient ?? ApiXlMovilProductPhotoClient();

  final SessionStore _sessionStore;
  final ProductsRepository _productsRepository;
  final CartRepository _cartRepository;
  final ApiXlMovilProductPhotoClient _photoClient;

  Future<({int idUsuario, String password})> _credentials() async {
    await AppRuntimeEndpoints.instance.refreshRemoteConfig();
    final creds = await _sessionStore.readExelCredentials();
    if (creds == null) throw Exception('Sesión incompleta. Vuelve a iniciar sesión.');
    final ids = await _sessionStore.readExelSecurityIds();
    if (ids == null) throw Exception('No se encontró el id de usuario.');
    final idUsuario = int.tryParse(ids.idUsuario);
    if (idUsuario == null || idUsuario <= 0) throw Exception('Id de usuario inválido.');
    return (idUsuario: idUsuario, password: creds.password);
  }

  /// Comprime y envía hasta 3 fotos. Devuelve cada producto detectado con
  /// sus coincidencias en el catálogo.
  Future<PhotoSearchResult> identifyAndSearch(List<String> filePaths) async {
    if (filePaths.isEmpty) throw Exception('Se requiere al menos una foto.');

    final compressed = await Future.wait(
      filePaths.take(3).map(QuoteImageCompressor.compressToBase64),
    );

    final creds = await _credentials();

    final response = await _photoClient.identificar(
      idUsuario: creds.idUsuario,
      password: creds.password,
      images: compressed
          .map((c) => (base64: c.base64, contentType: c.contentType))
          .toList(),
    );

    if (response.productos.isEmpty) {
      return PhotoSearchResult(response: response, detected: const []);
    }

    final detected = <DetectedProductMatch>[];
    for (final identification in response.productos) {
      final candidates = await _searchCascade(identification.searchQueries);
      detected.add(
        DetectedProductMatch(
          identification: identification,
          candidates: candidates,
          selected: candidates.isNotEmpty ? candidates.first : null,
        ),
      );
    }

    return PhotoSearchResult(response: response, detected: detected);
  }

  /// Intenta cada query en orden y devuelve los primeros resultados encontrados.
  Future<List<ProductCard>> _searchCascade(List<String> queries) async {
    for (final query in queries) {
      if (query.isEmpty) continue;
      try {
        final results = await _productsRepository.search(query);
        if (results.isNotEmpty) return results;
      } on Object {
        continue;
      }
    }
    return const [];
  }

  Future<bool> agregarAlCarrito({
    required String idProducto,
    required int cantidad,
  }) async {
    final idSucursal = await _cartRepository.readIdSucursalUsuario();
    if (idSucursal == null || idSucursal.isEmpty) {
      throw Exception('No se encontró sucursal del usuario.');
    }
    final result = await _cartRepository.agregarProducto(
      idProducto: idProducto,
      cantidad: cantidad,
      idLocalidad: idSucursal,
    );
    return result.ok;
  }
}
