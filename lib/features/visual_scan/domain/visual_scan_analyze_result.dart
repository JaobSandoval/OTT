import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_match_result.dart';
import 'package:exel_ott/features/visual_scan/domain/image_scan_classification.dart';

/// Resultado del análisis automático tras clasificar la imagen.
sealed class VisualScanAnalyzeResult {
  const VisualScanAnalyzeResult({required this.classification});

  final ImageScanClassification classification;
}

class VisualScanSearchAnalyzeResult extends VisualScanAnalyzeResult {
  const VisualScanSearchAnalyzeResult({
    required super.classification,
    required this.identification,
    required this.candidates,
  });

  final ProductIdentificationResult identification;
  final List<ProductCard> candidates;
}

class VisualScanQuoteAnalyzeResult extends VisualScanAnalyzeResult {
  const VisualScanQuoteAnalyzeResult({
    required super.classification,
    required this.matches,
    required this.observaciones,
    required this.estimatedTotal,
  });

  final List<QuoteLineMatch> matches;
  final String observaciones;
  final double estimatedTotal;
}
