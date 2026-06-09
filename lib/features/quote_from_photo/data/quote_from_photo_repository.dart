import 'dart:convert';

import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/data/apixlmovil_quote_client.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_image_compressor.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_registration_api.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_line.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_match_result.dart';
import 'package:uuid/uuid.dart';

class QuoteFromPhotoRepository {
  QuoteFromPhotoRepository({
    required SessionStore sessionStore,
    required ProductsRepository productsRepository,
    required CartRepository cartRepository,
    ApiXlMovilQuoteClient? quoteClient,
    QuoteRegistrationApi? registrationApi,
  })  : _sessionStore = sessionStore,
        _productsRepository = productsRepository,
        _cartRepository = cartRepository,
        _quoteClient = quoteClient ?? ApiXlMovilQuoteClient(),
        _registrationApi = registrationApi ?? QuoteRegistrationApi();

  final SessionStore _sessionStore;
  final ProductsRepository _productsRepository;
  final CartRepository _cartRepository;
  final ApiXlMovilQuoteClient _quoteClient;
  final QuoteRegistrationApi _registrationApi;
  final _uuid = const Uuid();

  static const _searchConcurrency = 3;

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

  Future<QuoteExtractionResult> extractFromImagePath(String filePath) async {
    final packed = await QuoteImageCompressor.compressToBase64(filePath);
    final creds = await _credentials();
    return _quoteClient.extraerLineasCotizacionImagen(
      idUsuario: creds.idUsuario,
      password: creds.password,
      imagenBase64: packed.base64,
      contentType: packed.contentType,
    );
  }

  Future<List<QuoteLineMatch>> searchMatches(List<QuoteLine> lineas) async {
    final matches = lineas
        .map((line) => QuoteLineMatch(line: line, searching: true))
        .toList();

    for (var i = 0; i < matches.length; i += _searchConcurrency) {
      final end = (i + _searchConcurrency).clamp(0, matches.length);
      await Future.wait(
        List.generate(end - i, (j) async {
          final index = i + j;
          final match = matches[index];
          try {
            final query = match.line.searchQuery;
            if (query.isEmpty) {
              matches[index] = match.copyWith(
                searching: false,
                searchError: 'Línea sin texto',
                clearSelected: true,
                candidates: const [],
              );
              return;
            }
            final results = await _productsRepository.search(query);
            matches[index] = match.copyWith(
              searching: false,
              candidates: results,
              selected: results.isNotEmpty ? results.first : null,
              searchError: results.isEmpty ? 'Sin coincidencias' : null,
            );
          } on Object catch (e) {
            matches[index] = match.copyWith(
              searching: false,
              searchError: e.toString(),
              clearSelected: true,
              candidates: const [],
            );
          }
        }),
      );
    }

    return matches;
  }

  /// Busca un producto por código de barras / SKU escaneado.
  /// Devuelve un [QuoteLineMatch] listo para agregar a la lista de coincidencias.
  Future<QuoteLineMatch> searchByBarcode(String barcode) async {
    final line = QuoteLine(texto: barcode, sku: barcode, cantidad: 1);
    try {
      final results = await _productsRepository.search(barcode);
      return QuoteLineMatch(
        line: line,
        candidates: results,
        selected: results.isNotEmpty ? results.first : null,
        searchError: results.isEmpty ? 'Sin coincidencias para "$barcode"' : null,
      );
    } on Object catch (e) {
      return QuoteLineMatch(
        line: line,
        candidates: const [],
        searchError: e.toString(),
      );
    }
  }

  Future<double> estimateTotal(List<QuoteLineMatch> matches) async {
    var total = 0.0;
    for (final match in matches) {
      final product = match.selected;
      if (product == null) continue;
      try {
        final raw = await _productsRepository.fetchPrecio(product.idProducto);
        final price = double.tryParse(raw?.replaceAll(',', '') ?? '') ?? 0;
        if (price > 0) {
          total += price * match.line.cantidad;
        }
      } on Object {
        // omitir línea sin precio
      }
    }
    return total;
  }

  Future<QuoteConfirmResult> confirmQuote({
    required List<QuoteLineMatch> matches,
    required String idEvento,
  }) async {
    final ids = await _sessionStore.readExelSecurityIds();
    final profile = await _sessionStore.readExelUserProfile();
    if (ids == null) {
      throw Exception('Sesión incompleta.');
    }

    final idSucursal = await _cartRepository.readIdSucursalUsuario();
    if (idSucursal == null || idSucursal.isEmpty) {
      throw Exception(
        'No se encontró sucursal del usuario. No se puede agregar al carrito.',
      );
    }

    final cotizados = <Map<String, dynamic>>[];
    final faltantes = <Map<String, dynamic>>[];

    for (final match in matches) {
      final lineJson = {
        'texto': match.line.texto,
        'sku': match.line.sku,
        'cantidad': match.line.cantidad,
      };
      if (match.selected != null) {
        cotizados.add({
          ...lineJson,
          'id_producto': match.selected!.idProducto,
          'descripcion': match.selected!.descripcion,
        });
      } else {
        faltantes.add(lineJson);
      }
    }

    final total = await estimateTotal(matches);
    final registered = await _registrationApi.registrarCotizacion(
      idEvento: idEvento,
      idUsuario: ids.idUsuario,
      idCliente: ids.idCliente,
      nombreCliente: profile?.name ?? '',
      total: total,
      productosDetectados: matches.length,
      productosEncontrados: cotizados.length,
      productosCotizados: jsonEncode(cotizados),
      productosFaltantes: faltantes.isEmpty ? null : jsonEncode(faltantes),
      idConversacion: 'mobile-$idEvento',
    );

    var added = 0;
    var failed = 0;
    for (final match in matches) {
      final product = match.selected;
      if (product == null) continue;
      try {
        final result = await _cartRepository.agregarProducto(
          idProducto: product.idProducto,
          cantidad: match.line.cantidad,
          idLocalidad: idSucursal,
        );
        if (result.ok) {
          added++;
        } else {
          failed++;
        }
      } on Object {
        failed++;
      }
    }

    return QuoteConfirmResult(
      registered: registered,
      addedCount: added,
      failedAdds: failed,
      skippedLines: faltantes.length,
    );
  }

  String newEventId() => _uuid.v4();

  ProductCard? pickBestMatch(List<ProductCard> results, QuoteLine line) {
    if (results.isEmpty) return null;
    final sku = line.sku.trim().toLowerCase();
    if (sku.isNotEmpty) {
      for (final p in results) {
        if (p.idProducto.toLowerCase() == sku) return p;
      }
    }
    return results.first;
  }
}
