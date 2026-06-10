import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/utils/currency_format.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:exel_ott/features/products/ui/product_add_to_cart_helpers.dart';
import 'package:exel_ott/features/products/ui/widgets/zoomable_product_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductCardTile extends StatefulWidget {
  const ProductCardTile({
    super.key,
    required this.product,
    required this.repository,
    this.cartRepository,
    this.catalogOnly = false,
    this.onTap,
  });

  final ProductCard product;
  final ProductsRepository repository;
  final CartRepository? cartRepository;
  final bool catalogOnly;
  final VoidCallback? onTap;

  @override
  State<ProductCardTile> createState() => _ProductCardTileState();
}

class _ProductCardTileState extends State<ProductCardTile> {
  String? _precio;
  bool _loadingPrecio = false;
  String? _existenciaSucursal;
  bool _loadingExistencia = false;
  bool _existenciaFetchDone = false;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    if (widget.catalogOnly) return;
    _hydratePrecioFromCache();
    _hydrateExistenciaFromCache();
    if (_precio == null) _loadPrecio();
    if (!_existenciaFetchDone) _loadExistencia();
  }

  @override
  void didUpdateWidget(covariant ProductCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.idProducto != widget.product.idProducto) {
      _hydratePrecioFromCache();
      _hydrateExistenciaFromCache();
      if (_precio == null && !_loadingPrecio) _loadPrecio();
      if (!_existenciaFetchDone && !_loadingExistencia) _loadExistencia();
    }
  }

  String? _pickStock(String? fetched, String fallback) {
    if (fetched != null && fetched.trim().isNotEmpty) return fetched.trim();
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return null;
  }

  String get _sucursalStock =>
      _pickStock(_existenciaSucursal, widget.product.existencia) ?? '';

  bool get _sucursalPending => _loadingExistencia && !_existenciaFetchDone;

  void _hydratePrecioFromCache() {
    if (widget.repository.hasCachedPrecio(widget.product.idProducto)) {
      _precio = widget.repository.getCachedPrecio(widget.product.idProducto);
      _loadingPrecio = false;
    } else {
      _precio = null;
      _loadingPrecio = false;
    }
  }

  void _hydrateExistenciaFromCache() {
    final cached =
        widget.repository.getCachedExistencia(widget.product.idProducto);
    if (cached != null) {
      _existenciaSucursal =
          cached.sucursal.isNotEmpty ? cached.sucursal : null;
      _existenciaFetchDone = true;
      _loadingExistencia = false;
    } else {
      _existenciaSucursal = null;
      _existenciaFetchDone = false;
      _loadingExistencia = false;
    }
  }

  Future<void> _loadPrecio() async {
    if (_loadingPrecio || _precio != null) return;
    if (widget.repository.hasCachedPrecio(widget.product.idProducto)) {
      setState(() {
        _precio = widget.repository.getCachedPrecio(widget.product.idProducto);
      });
      return;
    }
    setState(() => _loadingPrecio = true);
    try {
      final precio =
          await widget.repository.fetchPrecio(widget.product.idProducto);
      if (!mounted) return;
      setState(() {
        _precio = precio;
        _loadingPrecio = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loadingPrecio = false);
    }
  }

  Future<void> _loadExistencia() async {
    if (_loadingExistencia || _existenciaFetchDone) return;
    setState(() => _loadingExistencia = true);
    try {
      final summary =
          await widget.repository.fetchExistencia(widget.product.idProducto);
      if (!mounted) return;
      setState(() {
        _existenciaSucursal =
            summary.sucursal.isNotEmpty ? summary.sucursal : null;
        _existenciaFetchDone = true;
        _loadingExistencia = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _existenciaFetchDone = true;
        _loadingExistencia = false;
      });
    }
  }

  void _openDetail() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    context.push(
      '/home/products/detail/${widget.product.idProducto}',
      extra: widget.product,
    );
  }

  Future<void> _onAddToCart() async {
    if (_addingToCart || widget.catalogOnly) return;
    final cartRepository = widget.cartRepository;
    if (cartRepository == null) return;

    setState(() => _addingToCart = true);
    try {
      final detail =
          await widget.repository.fetchDetail(widget.product.idProducto);
      final idSucursal = await cartRepository.readIdSucursalUsuario();
      final pickable =
          cartRepository.pickableLocations(detail, idSucursal);

      if (pickable.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay sucursal con stock para agregar.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final quick = pickQuickAddLocation(pickable);
      if (quick == null) {
        if (!mounted) return;
        _openDetail();
        return;
      }

      if (!mounted) return;
      await addProductToCart(
        context: context,
        cartRepository: cartRepository,
        idProducto: detail.idProducto,
        selected: quick,
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo agregar: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppDecorations.softCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openDetail,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDecorations.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppDecorations.radiusLg),
                      ),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: AppColors.cardWhite,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: ZoomableProductImage(
                                  url: widget.product.imageUrl,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.catalogAccent,
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (widget.product.marca.isNotEmpty)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: _Chip(
                                  label: widget.product.marca,
                                  color: AppColors.catalogAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.descripcion.isNotEmpty
                                ? widget.product.descripcion
                                : widget.product.idProducto,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.product.idProducto,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.catalogOnly)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildPrecio(theme)),
                        Material(
                          color: AppColors.catalogAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _addingToCart ? null : _onAddToCart,
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: _addingToCart
                                  ? Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.catalogAccent,
                                      ),
                                    )
                                  : Icon(
                                      Icons.add_shopping_cart_outlined,
                                      size: 20,
                                      color: AppColors.catalogAccent,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StockChip(
                          label: 'Sucursal',
                          value: productStockLabel(
                            _sucursalStock,
                            pending: _sucursalPending,
                          ),
                          color: AppColors.catalogAccent,
                          isBackorder: !_sucursalPending &&
                              !productHasStock(_sucursalStock),
                          isPending: _sucursalPending,
                        ),
                        _StockChip(
                          label: 'Nacional',
                          value: productStockLabel(
                            widget.product.existenciaNacional,
                          ),
                          color: AppColors.catalogAccentAlt,
                          isBackorder: !productHasStock(
                            widget.product.existenciaNacional,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPrecio(ThemeData theme) {
    if (_loadingPrecio) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.catalogAccent,
        ),
      );
    }
    if (_precio != null && _precio!.isNotEmpty) {
      return Text(
        formatCurrency(_precio!),
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.catalogAccent,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return Text(
      'Precio no disponible',
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.label,
    required this.value,
    required this.color,
    this.isBackorder = false,
    this.isPending = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool isBackorder;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final displayColor = isPending
        ? AppColors.textSecondary
        : isBackorder
            ? AppColors.error
            : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label · $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: displayColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
