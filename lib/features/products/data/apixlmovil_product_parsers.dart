import 'dart:convert';

import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';

class ApiXlMovilProductParsers {
  const ApiXlMovilProductParsers._();

  static List<ProductCard> parseBuscador(String payload) {
    final decoded = _decodeJson(payload);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => ProductCard.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.idProducto.isNotEmpty)
        .toList();
  }

  static String? parsePrecio(String payload) {
    final decoded = _decodeJson(payload);
    final map = _firstMap(decoded);
    if (map == null) return null;
    final precio = _pick(map, ['precio', 'Precio']);
    return precio.isEmpty ? null : precio;
  }

  static ({
    String sucursal,
    String nacional,
    String? precio,
    String? imageUrl,
  }) parseExistenciaSummary(
    String payload, {
    String? idLocalidadUsuario,
    String? sucursalNombreUsuario,
  }) {
    final map = _firstMap(_decodeJson(payload)) ?? {};
    return _parseExistenciaFromMap(
      map,
      idLocalidadUsuario: idLocalidadUsuario,
      sucursalNombreUsuario: sucursalNombreUsuario,
    );
  }

  /// Varias filas cuando `id_producto` llega como lista separada por comas.
  static Map<String, ({
    String sucursal,
    String nacional,
    String? precio,
    String? imageUrl,
  })> parseExistenciaSummaryBatch(
    String payload, {
    required List<String> requestedIds,
    String? idLocalidadUsuario,
    String? sucursalNombreUsuario,
  }) {
    final maps = _productMapsFromPayload(_decodeJson(payload));
    final byId = <String, ({
      String sucursal,
      String nacional,
      String? precio,
      String? imageUrl,
    })>{};

    for (final map in maps) {
      final id = _pick(map, ['id_producto', 'Id_Producto']);
      if (id.isEmpty) continue;
      byId[id] = _parseExistenciaFromMap(
        map,
        idLocalidadUsuario: idLocalidadUsuario,
        sucursalNombreUsuario: sucursalNombreUsuario,
      );
    }

    return {
      for (final id in requestedIds)
        id: byId[id] ??
            const (
              sucursal: '',
              nacional: '',
              precio: null,
              imageUrl: null,
            ),
    };
  }

  static ({
    String sucursal,
    String nacional,
    String? precio,
    String? imageUrl,
  }) _parseExistenciaFromMap(
    Map<String, dynamic> map, {
    String? idLocalidadUsuario,
    String? sucursalNombreUsuario,
  }) {
    final precioRaw = _pick(map, ['precio', 'Precio']);
    final precio = precioRaw.isEmpty ? null : precioRaw;
    final imagenesZoom = _parseZoomImagenes(map['imagenes']);
    final imageUrl = imagenesZoom.isNotEmpty ? imagenesZoom.first : null;

    var sucursal = _pick(map, [
      'Existencia',
      'existencia',
      'Existencia_Sucursal',
      'existencia_sucursal',
    ]);
    var nacional = _pick(map, [
      'ExistenciaNacional',
      'existenciaNacional',
      'existencia_MX',
      'Existencia_MX',
    ]);

    final existenciasRaw = map['existencias'];
    var nacionalFromList = 0;
    var sucursalFromList = '';

    if (existenciasRaw is List) {
      for (final item in existenciasRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final existencia = _pick(row, ['existencia', 'Existencia']);
        final localidad = _pick(row, ['localidad', 'Localidad']);
        final idLoc = _pick(row, ['id_localidad', 'idLocalidad', 'Id_Localidad']);
        final qty = parseStockQuantity(existencia) ?? 0;
        nacionalFromList += qty;

        final idMatch = idLocalidadUsuario != null &&
            idLocalidadUsuario.isNotEmpty &&
            idLoc.isNotEmpty &&
            idLoc == idLocalidadUsuario;
        final nameMatch = sucursalNombreUsuario != null &&
            sucursalNombreUsuario.isNotEmpty &&
            localidad.isNotEmpty &&
            localidad.toLowerCase() == sucursalNombreUsuario.toLowerCase();

        if ((idMatch || nameMatch) && qty > 0) {
          sucursalFromList =
              existencia.isNotEmpty ? existencia : '$qty';
        }
      }
    }

    if (sucursal.isEmpty && sucursalFromList.isNotEmpty) {
      sucursal = sucursalFromList;
    }
    if (nacional.isEmpty && nacionalFromList > 0) {
      nacional = '$nacionalFromList';
    }

    return (
      sucursal: sucursal,
      nacional: nacional,
      precio: precio,
      imageUrl: imageUrl,
    );
  }

  static ProductDetail parsePublicDetail({
    required String idProducto,
    required String fichaPayload,
    ProductCard? card,
  }) {
    return ProductDetail(
      idProducto: card?.idProducto.isNotEmpty == true
          ? card!.idProducto
          : idProducto,
      descripcion: card?.descripcion ?? '',
      marca: card?.marca ?? '',
      precio: '',
      codigoProveedor: '',
      fichaTecnica: parseFichaTecnica(fichaPayload),
      existencias: const [],
      imagenesZoom: [
        card?.imageUrl ??
            'https://contenidos.exel.com.mx/imgProducto/$idProducto.png',
      ],
    );
  }

  static ProductDetail parseDetail({
    required String idProducto,
    required String existenciaPayload,
    required String fichaPayload,
    String? idLocalidadUsuario,
  }) {
    final existenciaDecoded = _decodeJson(existenciaPayload);
    final map = _firstMap(existenciaDecoded) ?? {};

    final descripcion = _pick(map, ['descripcion', 'Descripcion']);
    final marca = _pick(map, ['marca', 'Marca']);
    final precio = _pick(map, ['precio', 'Precio']);
    final codigoProveedor = _pick(map, ['codigo_proveedor', 'codigoProveedor']);
    final id = _pick(map, ['id_producto', 'Id_Producto']).isEmpty
        ? idProducto
        : _pick(map, ['id_producto', 'Id_Producto']);

    final imagenesZoom = _parseZoomImagenes(map['imagenes']);

    final existencias = <ExistenciaSucursal>[];
    final existenciasRaw = map['existencias'];
    if (existenciasRaw is List) {
      for (final item in existenciasRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final localidad = _pick(row, ['localidad', 'Localidad']);
        final existencia = _pick(row, ['existencia', 'Existencia']);
        if (localidad.isEmpty) continue;
        final idLoc = _pick(row, ['id_localidad', 'idLocalidad', 'Id_Localidad']);
        final esSucursal = idLocalidadUsuario != null &&
            idLocalidadUsuario.isNotEmpty &&
            idLoc.isNotEmpty &&
            idLoc == idLocalidadUsuario;
        existencias.add(
          ExistenciaSucursal(
            idLocalidad: idLoc,
            localidad: localidad,
            existencia: existencia,
            esSucursalUsuario: esSucursal,
          ),
        );
      }
    }

    existencias.sort((a, b) {
      if (a.esSucursalUsuario != b.esSucursalUsuario) {
        return a.esSucursalUsuario ? -1 : 1;
      }
      final ea = parseStockQuantity(a.existencia) ?? 0;
      final eb = parseStockQuantity(b.existencia) ?? 0;
      return eb.compareTo(ea);
    });

    return ProductDetail(
      idProducto: id,
      descripcion: descripcion,
      marca: marca,
      precio: precio,
      codigoProveedor: codigoProveedor,
      fichaTecnica: parseFichaTecnica(fichaPayload),
      existencias: existencias,
      imagenesZoom: imagenesZoom,
    );
  }

  static List<String> _parseZoomImagenes(dynamic imagenes) {
    if (imagenes is! List) return const [];
    final urls = <String>[];
    for (final item in imagenes) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final tipo = _pick(row, ['tipo', 'Tipo']).toLowerCase();
      if (tipo != 'zoom') continue;
      final url = _pick(row, ['url', 'Url']);
      if (url.isNotEmpty) urls.add(url);
    }
    return urls;
  }

  static List<FichaTecnicaRow> parseFichaTecnica(String payload) {
    final decoded = _decodeJson(payload);
    if (decoded is! List) return const [];

    final rows = <FichaTecnicaRow>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map.isEmpty) continue;

      String caracteristica = '';
      String valor = '';

      if (map.containsKey('Caracteristica') || map.containsKey('caracteristica')) {
        caracteristica = _pick(map, ['Caracteristica', 'caracteristica']);
        valor = _pick(map, ['Valor', 'valor']);
      } else if (map.length >= 2) {
        final keys = map.keys.toList();
        caracteristica = map[keys[0]]?.toString() ?? '';
        valor = map[keys[1]]?.toString() ?? '';
      } else if (map.length == 1) {
        final k = map.keys.first;
        caracteristica = k;
        valor = map[k]?.toString() ?? '';
      }

      if (caracteristica.isEmpty && valor.isEmpty) continue;
      rows.add(FichaTecnicaRow(caracteristica: caracteristica, valor: valor));
    }
    return rows;
  }

  static dynamic _decodeJson(String payload) {
    try {
      return jsonDecode(payload);
    } on Object {
      final unescaped = payload
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"');
      return jsonDecode(unescaped);
    }
  }

  static Map<String, dynamic>? _firstMap(dynamic decoded) {
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static List<Map<String, dynamic>> _productMapsFromPayload(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      for (final key in const [
        'productos',
        'Productos',
        'items',
        'Items',
        'data',
        'Data',
      ]) {
        final inner = map[key];
        if (inner is List) {
          return inner
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [map];
    }
    return const [];
  }

  static String _pick(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }
}
