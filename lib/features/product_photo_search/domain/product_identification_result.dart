class ProductIdentificationResult {
  const ProductIdentificationResult({
    required this.nombre,
    required this.marca,
    required this.sku,
    required this.categoria,
    required this.descripcion,
    required this.keywords,
    required this.confianza,
    required this.modeloUsado,
    required this.imagenesAnalizadas,
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

  static ProductIdentificationResult fromJson(Map<String, dynamic> json) {
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
      modeloUsado: (json['modelo_usado'] as String? ?? '').trim(),
      imagenesAnalizadas: (json['imagenes_analizadas'] as int?) ?? 1,
    );
  }
}
