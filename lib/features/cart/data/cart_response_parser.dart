import 'dart:convert';

import 'package:exel_ott/features/cart/domain/cart_item.dart';
import 'package:exel_ott/features/cart/domain/cart_operation_result.dart';

class CartResponseParser {
  const CartResponseParser._();

  static CartOperationResult parseOperation(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      return const CartOperationResult(
        ok: false,
        mensaje: 'Respuesta vacía del servidor',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return _operationFromMap(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // No es JSON; tratar como éxito legacy si no hay error obvio
    }

    if (trimmed.contains('Cuenta no válida') ||
        trimmed.contains('no válida')) {
      return const CartOperationResult(ok: false, mensaje: 'Cuenta no válida');
    }

    return const CartOperationResult(
      ok: true,
      mensaje: 'Operación completada',
    );
  }

  static CartOperationResult _operationFromMap(Map<String, dynamic> map) {
    final mensaje = _pick(map, ['mensaje', 'Mensaje']);
    if (map.containsKey('mensaje') &&
        mensaje.contains('no válida') &&
        !map.containsKey('ok')) {
      return CartOperationResult(ok: false, mensaje: mensaje);
    }

    final okRaw = map['ok'];
    final ok = okRaw == true ||
        okRaw == 'true' ||
        (okRaw == null && !mensaje.toLowerCase().contains('error'));

    final cantidadFinal = _parseInt(map['cantidad_final'] ?? map['cantidadFinal']);

    if (okRaw == false || okRaw == 'false') {
      return CartOperationResult(
        ok: false,
        mensaje: mensaje.isEmpty ? 'Error en el carrito' : mensaje,
        cantidadFinal: cantidadFinal,
      );
    }

    return CartOperationResult(
      ok: ok,
      mensaje: mensaje.isEmpty ? 'Operación completada' : mensaje,
      cantidadFinal: cantidadFinal,
    );
  }

  static List<CartItem> parseConsultaCarrito(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty || trimmed == '[]') return const [];

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => _itemFromMap(Map<String, dynamic>.from(e)))
            .where((i) => i.idProducto.isNotEmpty)
            .toList();
      }
      if (decoded is Map) {
        final items = decoded['items'] ?? decoded['Items'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((e) => _itemFromMap(Map<String, dynamic>.from(e)))
              .where((i) => i.idProducto.isNotEmpty)
              .toList();
        }
      }
    } on FormatException {
      return const [];
    }
    return const [];
  }

  static CartItem _itemFromMap(Map<String, dynamic> map) {
    return CartItem(
      idProducto: _pick(map, ['id_producto', 'Id_Producto', 'idProducto']),
      idLocalidad: _pick(map, ['id_localidad', 'Id_Localidad', 'idLocalidad']),
      cantidad: _parseInt(map['cantidad'] ?? map['Cantidad']) ?? 0,
      descripcion: _pick(map, ['descripcion', 'Descripcion', 'producto', 'Producto']),
      codigoProveedor: _pick(map, [
        'codigo_proveedor',
        'Codigo_Proveedor',
        'codigoProveedor',
      ]),
      precioUnitario: _parseDouble(
        map['precio_unitario'] ??
            map['Precio_Unitario'] ??
            map['precioUnitario'] ??
            map['Precio'] ??
            map['precio'],
      ),
      cantidadSurtida: _parseInt(
        map['cantidad_surtida'] ?? map['Cantidad_Surtida'],
      ),
      localidad: _pick(map, [
        'localidad',
        'Localidad',
        'sucursal',
        'Sucursal',
        'nombre_localidad',
        'Nombre_Localidad',
        'nombre_sucursal',
        'Nombre_Sucursal',
        'almacen',
        'Almacen',
      ]),
    );
  }

  static String _pick(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString().trim());
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }
}
