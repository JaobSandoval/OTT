import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';

/// Producto detectado por IA con sus coincidencias en el catálogo.
class DetectedProductMatch {
  const DetectedProductMatch({
    required this.identification,
    required this.candidates,
    this.selected,
  });

  final ProductIdentificationResult identification;
  final List<ProductCard> candidates;
  final ProductCard? selected;

  DetectedProductMatch copyWith({
    ProductIdentificationResult? identification,
    List<ProductCard>? candidates,
    ProductCard? selected,
    bool clearSelected = false,
  }) {
    return DetectedProductMatch(
      identification: identification ?? this.identification,
      candidates: candidates ?? this.candidates,
      selected: clearSelected ? null : (selected ?? this.selected),
    );
  }
}

/// Resultado de identificar y buscar en catálogo (uno o varios productos).
class PhotoSearchResult {
  const PhotoSearchResult({
    required this.response,
    required this.detected,
  });

  final PhotoIdentificationResponse response;
  final List<DetectedProductMatch> detected;

  ProductIdentificationResult? get primaryIdentification => response.primary;

  List<ProductCard> get allCandidates =>
      detected.expand((match) => match.candidates).toList();
}
