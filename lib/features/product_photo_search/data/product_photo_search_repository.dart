import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/product_photo_search/data/apixlmovil_product_photo_client.dart';
import 'package:exel_ott/features/product_photo_search/domain/detected_product_match.dart';
import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
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
      var candidates = await _resolveIntelligentCandidates(identification);
      if (candidates.isEmpty) {
        // El buscador inteligente (apiCotizadorNew) no respondió, no está
        // configurado o no encontró nada: cae al comportamiento anterior
        // (búsqueda de texto directa contra XL_Sel_Buscador_IA + ranking
        // por marca en el cliente), para que la foto siga funcionando igual
        // que antes de esta integración.
        candidates = await _searchForIdentification(identification);
      }
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

  /// Resuelve contra el catálogo en vivo (precio/existencia reales) los
  /// candidatos que ya rankeó el buscador inteligente (motor FTS5+scoring +
  /// validación de relevancia por IA en apiCotizadorNew), preservando ese
  /// orden y moviendo al frente el que la IA marcó como el elegido.
  Future<List<ProductCard>> _resolveIntelligentCandidates(
    ProductIdentificationResult identification,
  ) async {
    final candidatos = identification.candidatosInteligentes;
    if (candidatos.isEmpty) return const [];

    final ids = candidatos
        .map((c) => c.idProducto)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];

    final resolved = await Future.wait(ids.map(_lookupProductById));

    final byId = <String, ProductCard>{};
    for (final card in resolved) {
      if (card != null) byId[card.idProducto] = card;
    }
    if (byId.isEmpty) return const [];

    final ordered = <ProductCard>[
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];

    final seleccionadoId = identification.seleccionadoInteligenteId;
    final seleccionado = seleccionadoId != null ? byId[seleccionadoId] : null;
    if (seleccionado != null) {
      ordered.remove(seleccionado);
      ordered.insert(0, seleccionado);
    }

    return ordered;
  }

  /// Busca un producto por su id exacto en el catálogo en vivo (mismo patrón
  /// que `ProductsRepository._lookupPublicCard`): el motor de búsqueda ya
  /// indexa el id/código, así que buscarlo como texto y confirmar la
  /// coincidencia exacta evita necesitar un endpoint nuevo "por ids".
  Future<ProductCard?> _lookupProductById(String id) async {
    try {
      final results = await _productsRepository.search(id);
      for (final product in results) {
        if (product.idProducto == id) return product;
      }
    } on Object {
      // El candidato no se pudo resolver contra SQL en vivo (id descontinuado,
      // desincronizado con el catálogo CSV de apiCotizadorNew, etc.) — se
      // omite en vez de romper el resto de los candidatos.
    }
    return null;
  }

  /// Intenta cada combinación query+filtros y devuelve los mejores resultados.
  Future<List<ProductCard>> _searchForIdentification(
    ProductIdentificationResult identification,
  ) async {
    for (final attempt in identification.catalogSearchAttempts) {
      if (attempt.query.isEmpty && !attempt.filters.hasAny) continue;
      try {
        final results = await _productsRepository.search(
          attempt.query,
          filters: attempt.filters,
        );
        if (results.isNotEmpty) {
          return _rankCandidates(results, identification.marca);
        }
      } on Object {
        continue;
      }
    }
    return const [];
  }

  /// Prioriza candidatos cuya marca coincide con la detectada por IA.
  List<ProductCard> _rankCandidates(List<ProductCard> results, String marca) {
    if (marca.isEmpty) return results;

    final marcaLower = marca.trim().toLowerCase();
    final matching = results
        .where((p) => p.marca.trim().toLowerCase() == marcaLower)
        .toList();
    if (matching.isEmpty) return results;

    final nonMatching = results
        .where((p) => p.marca.trim().toLowerCase() != marcaLower)
        .toList();
    return [...matching, ...nonMatching];
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
