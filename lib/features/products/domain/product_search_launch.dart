import 'package:exel_ott/features/products/domain/product_search_filters.dart';

/// Parámetros para abrir el buscador (público o con sesión) con texto y filtros.
class ProductSearchLaunch {
  const ProductSearchLaunch({
    this.query,
    this.filters = const ProductSearchFilters(),
  });

  final String? query;
  final ProductSearchFilters filters;

  bool get shouldSearch =>
      (query?.trim().isNotEmpty ?? false) || filters.hasAny;

  /// Texto enviado al API. Si solo hay filtros, usa comodín.
  String get apiQuery {
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) return q;
    if (filters.hasAny) return '%';
    return '';
  }

  Uri uri({required bool publicCatalog}) {
    final params = <String, String>{};
    final q = query?.trim();
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (filters.idMarca.isNotEmpty) params['marca'] = filters.idMarca;
    if (filters.idCategoria.isNotEmpty) {
      params['categoria'] = filters.idCategoria;
    }
    if (filters.idSubcategoria.isNotEmpty) {
      params['subcategoria'] = filters.idSubcategoria;
    }
    return Uri(
      path: publicCatalog ? '/catalog' : '/home/products',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  static ProductSearchLaunch fromQueryParams(Map<String, String> params) {
    return ProductSearchLaunch(
      query: params['q'],
      filters: ProductSearchFilters(
        idMarca: params['marca']?.trim() ?? '',
        idCategoria: params['categoria']?.trim() ?? '',
        idSubcategoria: params['subcategoria']?.trim() ?? '',
      ),
    );
  }

  ProductSearchLaunch copyWith({
    String? query,
    ProductSearchFilters? filters,
  }) {
    return ProductSearchLaunch(
      query: query ?? this.query,
      filters: filters ?? this.filters,
    );
  }
}
