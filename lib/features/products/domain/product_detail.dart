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

/// Etiqueta de existencia para la lista de productos.
String productStockLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Backorder';
  final qty = int.tryParse(trimmed);
  if (qty == null || qty <= 0) return 'Backorder';
  return trimmed;
}

bool productHasStock(String raw) => productStockLabel(raw) != 'Backorder';
