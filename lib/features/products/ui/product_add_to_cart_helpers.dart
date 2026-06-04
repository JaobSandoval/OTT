import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/cart/domain/cart_operation_result.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef PickableLocation = ({ExistenciaSucursal row, String locationId});

/// Sucursal del usuario, única disponible, o null si hay que elegir en detalle.
PickableLocation? pickQuickAddLocation(List<PickableLocation> pickable) {
  if (pickable.isEmpty) return null;

  final userBranch = pickable.where((p) => p.row.esSucursalUsuario).toList();
  if (userBranch.length == 1) return userBranch.first;
  if (pickable.length == 1) return pickable.first;
  return null;
}

void showCartSnackBar(BuildContext context, CartOperationResult result) {
  final messenger = ScaffoldMessenger.of(context);
  final message = result.ok
      ? (result.mensaje.isNotEmpty
          ? result.mensaje
          : 'Producto agregado al carrito')
      : (result.mensaje.isNotEmpty
          ? result.mensaje
          : 'No se pudo agregar al carrito');

  if (!result.ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
    return;
  }

  // SnackBarAction impide el auto-cierre aunque se defina duration.
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(
            onPressed: () {
              messenger.hideCurrentSnackBar();
              context.push('/home/cart');
            },
            child: const Text('Ver carrito'),
          ),
        ],
      ),
      duration: const Duration(seconds: 5),
    ),
  );
}

Future<int?> showAddToCartQuantityDialog(
  BuildContext context, {
  required int maxStock,
  required String sucursal,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _QuantityDialog(
      maxStock: maxStock,
      sucursal: sucursal,
    ),
  );
}

Future<bool> addProductToCart({
  required BuildContext context,
  required CartRepository cartRepository,
  required String idProducto,
  required PickableLocation selected,
}) async {
  final quantity = await showAddToCartQuantityDialog(
    context,
    maxStock: parseStockQuantity(selected.row.existencia) ?? 999,
    sucursal: selected.row.localidad,
  );
  if (quantity == null || quantity < 1) return false;

  try {
    final result = await cartRepository.agregarProducto(
      idProducto: idProducto,
      cantidad: quantity,
      idLocalidad: selected.locationId,
      localidadNombre: selected.row.localidad,
    );
    if (!context.mounted) return false;
    showCartSnackBar(context, result);
    return result.ok;
  } on Object catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyErrorMessage(e)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
    return false;
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.maxStock,
    required this.sucursal,
  });

  final int maxStock;
  final String sucursal;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(_controller.text.trim()) ?? 0;
    final exceeds = qty > widget.maxStock;

    return AlertDialog(
      title: const Text('Cantidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sucursal: ${widget.sucursal}'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (exceeds && widget.maxStock > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Solo hay ${widget.maxStock} en stock; el excedente puede ir como backorder.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: qty >= 1 ? () => Navigator.pop(context, qty) : null,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
