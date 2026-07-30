import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/core/permissions/image_scan_permission_service.dart';
import 'dart:async';

import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/logtool/lt_log_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:exel_ott/features/products/domain/product_search_launch.dart';
import 'package:exel_ott/features/products/ui/widgets/product_card_tile.dart';
import 'package:exel_ott/features/products/ui/widgets/products_filters_bar.dart';
import 'package:exel_ott/features/visual_scan/ui/visual_scan_lens_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.productsRepository,
    required this.cartRepository,
    required this.imageScanPermission,
    this.initialLaunch,
  });

  final ProductsRepository productsRepository;
  final CartRepository cartRepository;
  final ImageScanPermissionService imageScanPermission;
  final ProductSearchLaunch? initialLaunch;

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

  List<ProductCard> _newProducts = const [];
  bool _loadingNewProducts = false;
  String? _newProductsError;

  @override
  void initState() {
    super.initState();
    AppRuntimeEndpoints.instance.refreshRemoteConfig();
    final launch = widget.initialLaunch;
    if (launch != null && launch.shouldSearch) {
      final q = launch.query?.trim();
      if (q != null && q.isNotEmpty) {
        _searchController.text = q;
      }
      _filters = launch.filters;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(applyInitialFilters: launch.filters.hasAny);
      });
    } else {
      _loadNewProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNewProducts() async {
    setState(() {
      _loadingNewProducts = true;
      _newProductsError = null;
    });
    try {
      final list = await widget.productsRepository.fetchProductosNuevos();
      if (!mounted) return;
      await widget.productsRepository.prepareProductExtrasList(list);
      if (!mounted) return;
      setState(() {
        _newProducts = list;
        _loadingNewProducts = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingNewProducts = false;
        _newProductsError = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _runSearch({bool applyInitialFilters = false}) async {
    final query = _searchController.text.trim();
    final pendingFilters = applyInitialFilters ? _filters : const ProductSearchFilters();
    final hasFilters = applyInitialFilters ? pendingFilters.hasAny : _filters.hasAny;

    if (query.isEmpty && !hasFilters) {
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

    final apiQuery = query.isNotEmpty ? query : '%';

    widget.productsRepository.clearPrecioCache();
    setState(() {
      _loading = true;
      _error = null;
      _catalogProducts = const [];
      _products = const [];
      _activeQuery = query.isNotEmpty ? query : 'Filtros activos';
      if (!applyInitialFilters) {
        _filters = const ProductSearchFilters();
      }
    });

    try {
      final apiFilters =
          applyInitialFilters ? pendingFilters : const ProductSearchFilters();
      final results = await widget.productsRepository.search(
        apiQuery,
        filters: apiFilters,
      );
      if (!mounted) return;
      await widget.productsRepository.prepareProductExtrasList(results);
      if (!mounted) return;

      final filters = applyInitialFilters
          ? sanitizeFilters(results, pendingFilters)
          : const ProductSearchFilters();
      final filtered = applyInitialFilters
          ? applyProductFilters(results, filters)
          : results;

      setState(() {
        _catalogProducts = results;
        _filters = filters;
        _products = filtered;
        _loading = false;
      });
      unawaited(LtLogService.instance.logAccion(
        pantalla: '/home/products',
        tipoOperacion: 'Busqueda',
        comentarios: 'Query: "$apiQuery", Resultados: ${results.length}',
      ));
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
    final filtered = applyProductFilters(_catalogProducts, sanitized);
    widget.productsRepository.prepareProductExtrasList(filtered);
    setState(() {
      _filters = sanitized;
      _products = filtered;
    });
  }

  void _clearFilters() {
    _onFiltersChanged(const ProductSearchFilters());
  }

  Future<void> _openVisualLens() async {
    if (!widget.imageScanPermission.loaded) {
      await widget.imageScanPermission.refresh();
    }
    if (!mounted) return;

    final allowPhoto = widget.imageScanPermission.imageScanEnabled;
    final result = await VisualScanLensSheet.open(
      context,
      allowPhotoCapture: allowPhoto,
    );
    if (result == null || !mounted) return;

    context.push('/home/visual-scan', extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterOptions =
        buildContextualFilterOptions(_catalogProducts, _filters);
    final isEmpty = _searchController.text.trim().isEmpty;
    final noResults = _products.isEmpty && !_loading && !isEmpty;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final listBottomPad = keyboardOpen ? 0.0 : 96.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: AppDecorations.softCard(radius: AppDecorations.radiusXl),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Buscar con foto',
                      onPressed: _openVisualLens,
                      icon: Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.catalogAccent.withValues(alpha: 0.9),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        gradient: AppDecorations.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        onPressed: _loading ? null : _runSearch,
                      ),
                    ),
                  ],
                ),
              ),
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
          if (_loading || _loadingNewProducts) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_products.length} resultado${_products.length == 1 ? '' : 's'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: isEmpty
                ? _buildNewProductsBrowse(context, listBottomPad)
                : noResults
                    ? _EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'Sin resultados.',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(bottom: listBottomPad),
                        itemCount: _products.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return ProductCardTile(
                            key: ValueKey(product.idProducto),
                            product: product,
                            listIndex: index,
                            repository: widget.productsRepository,
                            cartRepository: widget.cartRepository,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewProductsBrowse(BuildContext context, double listBottomPad) {
    final theme = Theme.of(context);

    if (_newProductsError != null && _newProducts.isEmpty) {
      return _EmptyState(
        icon: Icons.new_releases_outlined,
        message: _newProductsError!,
      );
    }

    if (_newProducts.isEmpty && !_loadingNewProducts) {
      return _EmptyState(
        icon: Icons.search_rounded,
        message: 'Escribe un término, usa la cámara para buscar con foto '
            'o pulsa buscar.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: listBottomPad),
      itemCount: _newProducts.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Row(
            children: [
              Icon(
                Icons.new_releases_outlined,
                size: 20,
                color: AppColors.catalogAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Productos nuevos',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }
        if (index == 1) {
          return Text(
            'Explora lo más reciente o busca arriba con texto o cámara.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          );
        }
        final productIndex = index - 2;
        final product = _newProducts[productIndex];
        return ProductCardTile(
          key: ValueKey('new-${product.idProducto}'),
          product: product,
          listIndex: productIndex,
          repository: widget.productsRepository,
          cartRepository: widget.cartRepository,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppDecorations.brandGradientSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
