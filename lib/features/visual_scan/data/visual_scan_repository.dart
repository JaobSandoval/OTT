import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/features/product_photo_search/data/product_photo_search_repository.dart';
import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_from_photo_repository.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_image_compressor.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_line.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_match_result.dart';
import 'package:exel_ott/features/visual_scan/data/apixlmovil_image_classify_client.dart';
import 'package:exel_ott/features/visual_scan/domain/image_scan_classification.dart';
import 'package:exel_ott/features/visual_scan/domain/visual_scan_analyze_result.dart';

/// Facade unificado: clasifica imagen y enruta a buscar producto o cotizar.
class VisualScanRepository {
  VisualScanRepository({
    required SessionStore sessionStore,
    required ProductPhotoSearchRepository productPhotoSearchRepository,
    required QuoteFromPhotoRepository quoteFromPhotoRepository,
    ApiXlMovilImageClassifyClient? classifyClient,
  })  : _sessionStore = sessionStore,
        _productPhoto = productPhotoSearchRepository,
        _quote = quoteFromPhotoRepository,
        _classifyClient = classifyClient ?? ApiXlMovilImageClassifyClient();

  final SessionStore _sessionStore;
  final ProductPhotoSearchRepository _productPhoto;
  final QuoteFromPhotoRepository _quote;
  final ApiXlMovilImageClassifyClient _classifyClient;

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

  Future<ImageScanClassification> classifyImage(String filePath) async {
    final packed = await QuoteImageCompressor.compressToBase64(filePath);
    final creds = await _credentials();
    return _classifyClient.clasificar(
      idUsuario: creds.idUsuario,
      password: creds.password,
      imagenBase64: packed.base64,
      contentType: packed.contentType,
    );
  }

  /// Clasifica la primera imagen y ejecuta el flujo correspondiente.
  Future<VisualScanAnalyzeResult> analyzePhotosAuto(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      throw Exception('Se requiere al menos una imagen.');
    }

    final classification = await classifyImage(filePaths.first);

    if (classification.isDocumento) {
      final extraction = await extractFromImagePaths(filePaths);
      final matches = await _quote.searchMatches(extraction.lineas);
      final total = await _quote.estimateTotal(matches);
      return VisualScanQuoteAnalyzeResult(
        classification: classification,
        matches: matches,
        observaciones: extraction.observaciones,
        estimatedTotal: total,
      );
    }

    final search = await _productPhoto.identifyAndSearch(filePaths);
    return VisualScanSearchAnalyzeResult(
      classification: classification,
      identification: search.identification,
      candidates: search.candidates,
    );
  }

  Future<({
    ProductIdentificationResult identification,
    List<ProductCard> candidates,
  })> identifyAndSearch(List<String> filePaths) {
    return _productPhoto.identifyAndSearch(filePaths);
  }

  Future<bool> agregarAlCarrito({
    required String idProducto,
    required int cantidad,
  }) {
    return _productPhoto.agregarAlCarrito(
      idProducto: idProducto,
      cantidad: cantidad,
    );
  }

  Future<QuoteExtractionResult> extractFromImagePaths(
    List<String> filePaths,
  ) async {
    if (filePaths.isEmpty) {
      throw Exception('Se requiere al menos una imagen.');
    }

    final allLines = <QuoteLine>[];
    final notes = <String>[];

    for (final path in filePaths) {
      try {
        final result = await _quote.extractFromImagePath(path);
        allLines.addAll(result.lineas);
        if (result.observaciones.isNotEmpty) {
          notes.add(result.observaciones);
        }
      } on Object {
        continue;
      }
    }

    if (allLines.isEmpty) {
      throw Exception(
        'No se detectaron líneas en las imágenes. Intenta con otra foto.',
      );
    }

    return QuoteExtractionResult(
      lineas: allLines,
      observaciones: notes.join('\n'),
    );
  }

  Future<List<QuoteLineMatch>> searchMatches(List<QuoteLine> lineas) {
    return _quote.searchMatches(lineas);
  }

  Future<QuoteLineMatch> searchByBarcode(String barcode) {
    return _quote.searchByBarcode(barcode);
  }

  Future<double> estimateTotal(List<QuoteLineMatch> matches) {
    return _quote.estimateTotal(matches);
  }

  Future<QuoteConfirmResult> confirmQuote({
    required List<QuoteLineMatch> matches,
    required String idEvento,
  }) {
    return _quote.confirmQuote(matches: matches, idEvento: idEvento);
  }

  String newEventId() => _quote.newEventId();
}
