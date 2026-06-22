class ProductIdentificationResult {
  const ProductIdentificationResult({
    required this.nombre,
    required this.marca,
    required this.sku,
    required this.categoria,
    required this.descripcion,
    required this.keywords,
    required this.confianza,
    this.modeloUsado = '',
    this.imagenesAnalizadas = 1,
  });

  final String nombre;
  final String marca;
  final String sku;
  final String categoria;
  final String descripcion;
  final List<String> keywords;

  /// 'alta' | 'media' | 'baja'
  final String confianza;
  final String modeloUsado;
  final int imagenesAnalizadas;

  bool get hasContent =>
      nombre.isNotEmpty ||
      marca.isNotEmpty ||
      sku.isNotEmpty ||
      keywords.isNotEmpty;

  String get displayName =>
      nombre.isNotEmpty ? nombre : (sku.isNotEmpty ? sku : 'Producto detectado');

  /// La query más relevante para buscar en el catálogo.
  /// Prioridad: SKU → nombre → primer keyword.
  String get bestSearchQuery {
    if (sku.isNotEmpty) return sku;
    if (nombre.isNotEmpty) return nombre;
    return keywords.isNotEmpty ? keywords.first : '';
  }

  /// Todas las queries posibles para búsqueda en cascada.
  List<String> get searchQueries {
    final queries = <String>{};
    if (sku.isNotEmpty) queries.add(sku);
    if (nombre.isNotEmpty) queries.add(nombre);
    queries.addAll(keywords);
    return queries.toList();
  }

  static ProductIdentificationResult fromJson(
    Map<String, dynamic> json, {
    String modeloUsado = '',
    int imagenesAnalizadas = 1,
  }) {
    return ProductIdentificationResult(
      nombre: (json['nombre'] as String? ?? '').trim(),
      marca: (json['marca'] as String? ?? '').trim(),
      sku: (json['sku'] as String? ?? '').trim(),
      categoria: (json['categoria'] as String? ?? '').trim(),
      descripcion: (json['descripcion'] as String? ?? '').trim(),
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      confianza: (json['confianza'] as String? ?? 'baja').trim().toLowerCase(),
      modeloUsado:
          modeloUsado.isNotEmpty
              ? modeloUsado
              : (json['modelo_usado'] as String? ?? '').trim(),
      imagenesAnalizadas:
          imagenesAnalizadas > 0
              ? imagenesAnalizadas
              : (json['imagenes_analizadas'] as int?) ?? 1,
    );
  }
}

/// Respuesta completa del API de identificación por foto (1 o más productos).
class PhotoIdentificationResponse {
  const PhotoIdentificationResponse({
    required this.productos,
    required this.modeloUsado,
    required this.imagenesAnalizadas,
  });

  final List<ProductIdentificationResult> productos;
  final String modeloUsado;
  final int imagenesAnalizadas;

  ProductIdentificationResult? get primary =>
      productos.isNotEmpty ? productos.first : null;

  static PhotoIdentificationResponse fromJson(Map<String, dynamic> json) {
    final modeloUsado = (json['modelo_usado'] as String? ?? '').trim();
    final imagenesAnalizadas = (json['imagenes_analizadas'] as int?) ?? 1;
    final productosRaw = json['productos'];

    if (productosRaw is List && productosRaw.isNotEmpty) {
      final productos = productosRaw
          .whereType<Map>()
          .map(
            (item) => ProductIdentificationResult.fromJson(
              Map<String, dynamic>.from(item),
              modeloUsado: modeloUsado,
              imagenesAnalizadas: imagenesAnalizadas,
            ),
          )
          .where((p) => p.hasContent)
          .toList();

      if (productos.isNotEmpty) {
        return PhotoIdentificationResponse(
          productos: productos,
          modeloUsado: modeloUsado,
          imagenesAnalizadas: imagenesAnalizadas,
        );
      }
    }

    final single = ProductIdentificationResult.fromJson(json);
    return PhotoIdentificationResponse(
      productos: single.hasContent ? [single] : const [],
      modeloUsado: modeloUsado.isNotEmpty ? modeloUsado : single.modeloUsado,
      imagenesAnalizadas:
          imagenesAnalizadas > 0 ? imagenesAnalizadas : single.imagenesAnalizadas,
    );
  }
}
