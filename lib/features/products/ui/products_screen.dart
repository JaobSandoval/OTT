import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:exel_ott/features/products/ui/widgets/product_card_tile.dart';
import 'package:exel_ott/features/products/ui/widgets/products_filters_bar.dart';
import 'package:flutter/material.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.productsRepository});

  final ProductsRepository productsRepository;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  List<ProductCard> _catalogProducts = const [];
  List<ProductCard> _products = const [];
  ProductSearchFilters _filters = const ProductSearchFilters();
  String _activeQuery = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppRuntimeEndpoints.instance.refreshRemoteConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _catalogProducts = const [];
        _products = const [];
        _activeQuery = '';
        _filters = const ProductSearchFilters();
        _error = null;
      });
      widget.productsRepository.clearPrecioCache();
      return;
    }

    widget.productsRepository.clearPrecioCache();
    setState(() {
      _loading = true;
      _error = null;
      _catalogProducts = const [];
      _products = const [];
      _activeQuery = query;
      _filters = const ProductSearchFilters();
    });

    try {
      final results = await widget.productsRepository.search(query);
      if (!mounted) return;

      setState(() {
        _catalogProducts = results;
        _products = results;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
        _catalogProducts = const [];
        _products = const [];
      });
    }
  }

  void _onFiltersChanged(ProductSearchFilters filters) {
    final sanitized = sanitizeFilters(_catalogProducts, filters);
    setState(() {
      _filters = sanitized;
      _products = applyProductFilters(_catalogProducts, _filters);
    });
  }

  void _clearFilters() {
    _onFiltersChanged(const ProductSearchFilters());
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions =
        buildContextualFilterOptions(_catalogProducts, _filters);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              labelText: 'Buscar producto',
              hintText: 'Código, descripción o marca',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _loading ? null : _runSearch,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_activeQuery.isNotEmpty && filterOptions.hasOptions) ...[
            const SizedBox(height: 12),
            ProductsFiltersBar(
              options: filterOptions,
              filters: _filters,
              onChanged: _onFiltersChanged,
              onClear: _clearFilters,
            ),
          ],
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _products.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'Escribe un término y pulsa buscar.'
                          : 'Sin resultados.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return ProductCardTile(
                        key: ValueKey(product.idProducto),
                        product: product,
                        repository: widget.productsRepository,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
