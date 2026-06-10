import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/cart/domain/cart_item.dart';
import 'package:flutter/material.dart';
import 'package:exel_ott/core/utils/currency_format.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.repository});

  final CartRepository repository;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _updatingKeys = {};

  String _itemKey(CartItem item) => '${item.idProducto}|${item.idLocalidad}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.consultaCarrito();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _adjustQuantity(CartItem item, int delta) async {
    final key = _itemKey(item);
    if (_updatingKeys.contains(key)) return;

    setState(() => _updatingKeys.add(key));
    try {
      final result = await widget.repository.ajustarCantidad(
        idProducto: item.idProducto,
        idLocalidad: item.idLocalidad,
        delta: delta,
      );
      if (!mounted) return;
      if (!result.ok) {
        _showMessage(
          result.mensaje.isNotEmpty
              ? result.mensaje
              : 'No se pudo actualizar la cantidad',
          isError: true,
        );
      }
      await _load();
    } on Object catch (e) {
      if (!mounted) return;
      _showMessage(friendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingKeys.remove(key));
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final key = _itemKey(item);
    if (_updatingKeys.contains(key)) return;

    setState(() => _updatingKeys.add(key));
    try {
      final result = await widget.repository.establecerCantidad(
        idProducto: item.idProducto,
        idLocalidad: item.idLocalidad,
        cantidad: 0,
      );
      if (!mounted) return;
      if (!result.ok) {
        _showMessage(
          result.mensaje.isNotEmpty
              ? result.mensaje
              : 'No se pudo eliminar el producto',
          isError: true,
        );
      }
      await _load();
    } on Object catch (e) {
      if (!mounted) return;
      _showMessage(friendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingKeys.remove(key));
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _openCheckout() {
    openExternalUrl(context, AppRuntimeEndpoints.instance.miCarritoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.catalogAccent,
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tu carrito está vacío',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega productos desde el catálogo',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _CartItemTile(
                        item: item,
                        updating: _updatingKeys.contains(_itemKey(item)),
                        onIncrease: () => _adjustQuantity(item, 1),
                        onDecrease: () => _adjustQuantity(item, -1),
                        onRemove: () => _removeItem(item),
                        formatPrice: formatCurrency,
                      );
                    },
                  ),
          ),
        ),
        if (_items.isNotEmpty)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              boxShadow: AppDecorations.softShadow,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_items.length} ${_items.length == 1 ? 'producto' : 'productos'} en el carrito',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Precios y disponibilidad sujetos a cambio sin previo aviso.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openCheckout,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Confirmar pedido en tienda'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Se abrirá XLStore para finalizar tu compra',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.updating,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.formatPrice,
  });

  final CartItem item;
  final bool updating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final String Function(num) formatPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.descripcion.isNotEmpty
        ? item.descripcion
        : item.codigoProveedor.isNotEmpty
            ? item.codigoProveedor
            : item.idProducto;

    return AppSoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 72,
                height: 72,
                color: AppColors.surface,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary,
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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.codigoProveedor.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.codigoProveedor,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.catalogAccent,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 14,
                      color: AppColors.catalogAccent,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.localidad.isNotEmpty
                            ? 'Sucursal: ${item.localidad}'
                            : item.idLocalidad.isNotEmpty
                                ? 'Sucursal: ${item.idLocalidad}'
                                : 'Sucursal no indicada',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.catalogAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.isBackorder) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Backorder',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.catalogAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (item.precioUnitario > 0) ...[
                  Text(
                    '${formatPrice(item.precioUnitario)} c/u · ${item.cantidad} uds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPrice(item.lineSubtotal),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.catalogAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else
                  Text(
                    'Precio en tienda',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
                tooltip: 'Eliminar',
                onPressed: updating ? null : onRemove,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onPressed: updating ? null : onDecrease,
                  ),
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: updating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.catalogAccent,
                              ),
                            )
                          : Text(
                              '${item.cantidad}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onPressed: updating ? null : onIncrease,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.catalogAccent),
        ),
      ),
    );
  }
}
