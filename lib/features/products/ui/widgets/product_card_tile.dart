import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductCardTile extends StatefulWidget {
  const ProductCardTile({
    super.key,
    required this.product,
    required this.repository,
  });

  final ProductCard product;
  final ProductsRepository repository;

  @override
  State<ProductCardTile> createState() => _ProductCardTileState();
}

class _ProductCardTileState extends State<ProductCardTile> {
  String? _precio;
  bool _loadingPrecio = false;

  @override
  void initState() {
    super.initState();
    _hydratePrecioFromCache();
    if (_precio == null) _loadPrecio();
  }

  @override
  void didUpdateWidget(covariant ProductCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.idProducto != widget.product.idProducto) {
      _hydratePrecioFromCache();
      if (_precio == null && !_loadingPrecio) {
        _loadPrecio();
      }
    }
  }

  void _hydratePrecioFromCache() {
    if (widget.repository.hasCachedPrecio(widget.product.idProducto)) {
      _precio = widget.repository.getCachedPrecio(widget.product.idProducto);
      _loadingPrecio = false;
    } else {
      _precio = null;
      _loadingPrecio = false;
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

  void _openDetail() {
    context.push(
      '/home/products/detail/${widget.product.idProducto}',
      extra: widget.product,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openDetail,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.product.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.marca.isNotEmpty
                          ? widget.product.marca
                          : '—',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.descripcion.isNotEmpty
                          ? widget.product.descripcion
                          : widget.product.idProducto,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.idProducto,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPrecio(theme),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ExistenciaBadge(
                          icon: Icons.storefront_outlined,
                          label: 'Sucursal',
                          value: productStockLabel(widget.product.existencia),
                          color: theme.colorScheme.primary,
                          isBackorder:
                              !productHasStock(widget.product.existencia),
                        ),
                        _ExistenciaBadge(
                          icon: Icons.public_outlined,
                          label: 'Nacional',
                          value: productStockLabel(
                            widget.product.existenciaNacional,
                          ),
                          color: theme.colorScheme.tertiary,
                          isBackorder: !productHasStock(
                            widget.product.existenciaNacional,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
          color: theme.colorScheme.primary,
        ),
      );
    }
    if (_precio != null && _precio!.isNotEmpty) {
      return Text(
        _formatPrecio(_precio!),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Text(
      'Precio no disponible',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _formatPrecio(String raw) {
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return raw.startsWith('\$') ? raw : '\$$raw';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _ExistenciaBadge extends StatelessWidget {
  const _ExistenciaBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isBackorder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isBackorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor =
        isBackorder ? theme.colorScheme.error : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: displayColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: displayColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: displayColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isBackorder
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
