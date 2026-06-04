class ProductDetail {
  const ProductDetail({
    required this.idProducto,
    required this.descripcion,
    required this.marca,
    required this.precio,
    required this.codigoProveedor,
    required this.fichaTecnica,
    required this.existencias,
    this.imagenesZoom = const [],
  });

  final String idProducto;
  final String descripcion;
  final String marca;
  final String precio;
  final String codigoProveedor;
  final List<FichaTecnicaRow> fichaTecnica;
  final List<ExistenciaSucursal> existencias;
  final List<String> imagenesZoom;

  String get imagenUrl => imagenesZoom.isNotEmpty
      ? imagenesZoom.first
      : 'https://contenidos.exel.com.mx/imgProducto/$idProducto.png';
}

class FichaTecnicaRow {
  const FichaTecnicaRow({
    required this.caracteristica,
    required this.valor,
  });

  final String caracteristica;
  final String valor;
}

class ExistenciaSucursal {
  const ExistenciaSucursal({
    required this.localidad,
    required this.existencia,
    this.idLocalidad = '',
    this.esSucursalUsuario = false,
  });

  final String idLocalidad;
  final String localidad;
  final String existencia;
  final bool esSucursalUsuario;
}

/// Cantidad numérica de existencia (acepta enteros, decimales y formatos del API).
int? parseStockQuantity(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final lower = trimmed.toLowerCase();
  if (lower == 'si' ||
      lower == 'sí' ||
      lower == 'yes' ||
      lower == 'disponible' ||
      lower == 'available') {
    return 1;
  }

  final asInt = int.tryParse(trimmed);
  if (asInt != null) return asInt;

  final normalized = trimmed.replaceAll(',', '');
  final asDouble = double.tryParse(normalized);
  if (asDouble != null) return asDouble.floor();

  final leadingNumber = RegExp(r'(\d+)').firstMatch(normalized);
  if (leadingNumber != null) {
    return int.tryParse(leadingNumber.group(1)!);
  }

  return null;
}

/// Etiqueta de existencia para la lista de productos.
String productStockLabel(String raw, {bool pending = false}) {
  if (pending) return '...';
  final qty = parseStockQuantity(raw);
  if (qty == null || qty <= 0) return 'Backorder';
  return '$qty';
}

bool productHasStock(String raw) => (parseStockQuantity(raw) ?? 0) > 0;
