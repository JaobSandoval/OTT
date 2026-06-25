import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:exel_ott/features/products/domain/product_search_launch.dart';
import 'package:exel_ott/features/products/ui/widgets/new_products_carousel.dart';
import 'package:exel_ott/features/welcome/ui/welcome_layout_metrics.dart';
import 'package:exel_ott/features/products/ui/widgets/product_card_tile.dart';
import 'package:exel_ott/features/products/ui/widgets/products_filters_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Catálogo público sin sesión: búsqueda, filtros por API y ficha técnica.
class PublicCatalogScreen extends StatefulWidget {
  const PublicCatalogScreen({
    super.key,
    required this.productsRepository,
    this.initialLaunch,
  });

  final ProductsRepository productsRepository;
  final ProductSearchLaunch? initialLaunch;

  @override
  State<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends State<PublicCatalogScreen> {
  final _searchController = TextEditingController();
  List<ProductCard> _catalogProducts = const [];
  List<ProductCard> _products = const [];
  ProductSearchFilters _filters = const ProductSearchFilters();
  String _activeQuery = '';
  bool _loading = false;
  String? _error;

  late final Future<List<ProductCard>> _newProductsFuture;

  @override
  void initState() {
    super.initState();
    _newProductsFuture = widget.productsRepository.fetchNewProducts();
    final launch = widget.initialLaunch;
    if (launch != null && launch.shouldSearch) {
      final q = launch.query?.trim();
      if (q != null && q.isNotEmpty) {
        _searchController.text = q;
      }
      _filters = launch.filters;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && !_filters.hasAny) {
      setState(() {
        _activeQuery = '';
        _catalogProducts = const [];
        _products = const [];
        _error = null;
      });
      return;
    }

    final apiQuery = query.isNotEmpty ? query : '%';

    setState(() {
      _loading = true;
      _error = null;
      _activeQuery = query.isNotEmpty ? query : _filtersLabel();
      _catalogProducts = const [];
      _products = const [];
    });

    try {
      final list = await widget.productsRepository.searchPublic(
        apiQuery,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _catalogProducts = list;
        _products = list;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  void _onFiltersChanged(ProductSearchFilters filters) {
    setState(() => _filters = filters);
    _runSearch();
  }

  void _clearFilters() {
    setState(() => _filters = const ProductSearchFilters());
    _runSearch();
  }

  String _filtersLabel() {
    final parts = <String>[];
    if (_filters.idMarca.isNotEmpty) parts.add('marca');
    if (_filters.idCategoria.isNotEmpty) parts.add('categoría');
    if (_filters.idSubcategoria.isNotEmpty) parts.add('subcategoría');
    if (parts.isEmpty) return '';
    return 'Filtro: ${parts.join(', ')}';
  }

  void _openDetail(ProductCard product) {
    context.push(
      '/catalog/detail/${product.idProducto}',
      extra: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final filterOptions =
        buildContextualFilterOptions(_catalogProducts, _filters);
    final hasSearch = _searchController.text.trim().isNotEmpty || _filters.hasAny;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppDecorations.brandGradient,
            ),
            padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () => context.go('/welcome'),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'Catálogo público',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Explora productos sin iniciar sesión. Sin precios ni compra.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyLarge,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'Buscar productos…',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: _loading ? null : _runSearch,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_catalogProducts.isNotEmpty || _filters.hasAny)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ProductsFiltersBar(
                options: filterOptions,
                filters: _filters,
                onChanged: _onFiltersChanged,
                onClear: _clearFilters,
              ),
            ),
          Expanded(
            child: _buildBody(theme, hasSearch),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
            child: OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Iniciar sesión para ver precios y comprar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool hasSearch) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _runSearch, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (!hasSearch && _activeQuery.isEmpty) {
      final metrics = WelcomeLayoutMetrics(MediaQuery.sizeOf(context).width);
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.horizontalPadding,
              0,
              metrics.horizontalPadding,
              6,
            ),
            child: Text(
              'Productos nuevos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          NewProductsCarousel(
            productsFuture: _newProductsFuture,
            itemWidth: metrics.newProductItemWidth,
            height: metrics.newProductsRowHeight,
            catalogOnly: true,
            horizontalPadding: metrics.horizontalPadding,
            spacing: metrics.gridSpacing,
            radius: metrics.bannerRadius,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Busca por nombre, marca o código',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mismo catálogo que XL-Store antes de iniciar sesión.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _activeQuery.isNotEmpty
                ? 'Sin resultados para "$_activeQuery".'
                : 'Sin resultados con los filtros seleccionados.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        AppSectionLabel(
          text:
              '${_products.length} resultado${_products.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 12),
        ..._products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ProductCardTile(
              product: product,
              repository: widget.productsRepository,
              catalogOnly: true,
              onTap: () => _openDetail(product),
            ),
          ),
        ),
      ],
    );
  }
}
