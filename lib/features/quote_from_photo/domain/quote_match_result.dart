import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_line.dart';

class QuoteLineMatch {
  QuoteLineMatch({
    required this.line,
    this.candidates = const [],
    ProductCard? selected,
    this.searchError,
    this.searching = false,
  }) : selected = selected ??
            (candidates.isNotEmpty ? candidates.first : null);

  final QuoteLine line;
  final List<ProductCard> candidates;
  ProductCard? selected;
  final String? searchError;
  final bool searching;

  bool get hasMatch => selected != null;

  QuoteLineMatch copyWith({
    QuoteLine? line,
    List<ProductCard>? candidates,
    ProductCard? selected,
    bool clearSelected = false,
    String? searchError,
    bool? searching,
  }) {
    return QuoteLineMatch(
      line: line ?? this.line,
      candidates: candidates ?? this.candidates,
      selected: clearSelected ? null : (selected ?? this.selected),
      searchError: searchError,
      searching: searching ?? this.searching,
    );
  }
}

class QuoteConfirmResult {
  const QuoteConfirmResult({
    required this.registered,
    required this.addedCount,
    required this.failedAdds,
    required this.skippedLines,
  });

  final bool registered;
  final int addedCount;
  final int failedAdds;
  final int skippedLines;
}
