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
    this.listIndex,
    this.onTap,
  });

  final ProductCard product;
  final ProductsRepository repository;
  final CartRepository? cartRepository;
  final bool catalogOnly;
  final int? listIndex;
  final VoidCallback? onTap;

  @override
  State<ProductCardTile> createState() => _ProductCardTileState();
}

class _ProductCardTileState extends State<ProductCardTile> {
  String? _precio;
  bool _loadingPrecio = false;
  String? _imageUrl;
  String? _existenciaSucursal;
  bool _loadingExistencia = false;
  bool _existenciaFetchDone = false;
  bool _addingToCart = false;
  String _sucursalLabel = 'SUCURSAL';

  @override
  void initState() {
    super.initState();
    if (widget.catalogOnly) return;
    _hydratePrecioFromCache();
    _hydrateImageFromCache();
    _hydrateExistenciaFromCache();
    _loadSucursalLabel();
    if (!_existenciaFetchDone) _loadCardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.catalogOnly || widget.listIndex == null) return;
    widget.repository.onProductListIndexVisible(widget.listIndex!);
  }

  Future<void> _loadSucursalLabel() async {
    final label = await widget.repository.userSucursalLabel();
    if (mounted) setState(() => _sucursalLabel = label);
  }

  @override
  void didUpdateWidget(covariant ProductCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.idProducto != widget.product.idProducto) {
      _hydratePrecioFromCache();
      _hydrateImageFromCache();
      _hydrateExistenciaFromCache();
      if (!_existenciaFetchDone && !_loadingExistencia) _loadCardData();
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

  void _hydrateImageFromCache() {
    final cached = widget.repository.getCachedImageUrl(widget.product.idProducto);
    _imageUrl = cached;
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

  Future<void> _loadCardData() async {
    if (_loadingExistencia || _existenciaFetchDone) return;
    setState(() {
      _loadingExistencia = true;
      if (_precio == null) _loadingPrecio = true;
    });
    try {
      final summary = await widget.repository.fetchExistencia(
        widget.product.idProducto,
        listIndex: widget.listIndex,
      );
      if (!mounted) return;
      setState(() {
        _existenciaSucursal =
            summary.sucursal.isNotEmpty ? summary.sucursal : null;
        _precio = summary.precio;
        _imageUrl = summary.imageUrl;
        _existenciaFetchDone = true;
        _loadingExistencia = false;
        _loadingPrecio = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _existenciaFetchDone = true;
        _loadingExistencia = false;
        _loadingPrecio = false;
      });
    }
  }

  String get _displayImageUrl => _imageUrl ?? widget.product.imageUrl;

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
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          ColoredBox(
                            color: AppColors.cardWhite,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Center(
                                child: ZoomableProductImage(
                                  url: _displayImageUrl,
                                  fit: BoxFit.scaleDown,
                                  enablePinchZoom: false,
                                  enableFullscreenOnTap: false,
                                  highQuality: true,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 48),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.catalogAccent,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
                    _ProductStockRow(
                      sucursalLabel: _sucursalLabel,
                      sucursalStock: _sucursalStock,
                      nacionalStock: widget.product.existenciaNacional,
                      sucursalPending: _sucursalPending,
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
      return const SizedBox(
        width: 80,
        child: LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: AppColors.borderLight,
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

class _ProductStockRow extends StatelessWidget {
  const _ProductStockRow({
    required this.sucursalLabel,
    required this.sucursalStock,
    required this.nacionalStock,
    required this.sucursalPending,
  });

  final String sucursalLabel;
  final String sucursalStock;
  final String nacionalStock;
  final bool sucursalPending;

  static const _labelColor = Color(0xFF334155);
  static const _valueColor = Color(0xFF71717A);
  static const _separatorColor = Color(0xFFD4D4D8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFullBackorder = !sucursalPending &&
        isProductFullyOutOfStock(sucursalStock, nacionalStock);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 4,
      children: [
        _StockEntry(
          theme: theme,
          label: sucursalLabel,
          value: productStockLabel(
            sucursalStock,
            pending: sucursalPending,
            asBackorder: isFullBackorder,
          ),
          isBackorder: isFullBackorder,
          isPending: sucursalPending,
          showLeadingSeparator: false,
        ),
        _StockEntry(
          theme: theme,
          label: 'NACIONAL',
          value: productStockLabel(
            nacionalStock,
            asBackorder: isFullBackorder,
          ),
          isBackorder: isFullBackorder,
          showLeadingSeparator: true,
        ),
      ],
    );
  }
}

class _StockEntry extends StatelessWidget {
  const _StockEntry({
    required this.theme,
    required this.label,
    required this.value,
    required this.isBackorder,
    this.isPending = false,
    this.showLeadingSeparator = true,
  });

  final ThemeData theme;
  final String label;
  final String value;
  final bool isBackorder;
  final bool isPending;
  final bool showLeadingSeparator;

  @override
  Widget build(BuildContext context) {
    final valueColor = isPending
        ? AppColors.textSecondary
        : isBackorder
            ? AppColors.catalogAccent
            : _ProductStockRow._valueColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLeadingSeparator)
          Text(
            '| ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: _ProductStockRow._separatorColor,
              fontWeight: FontWeight.w300,
            ),
          ),
        Text(
          '$label: ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: _ProductStockRow._labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
