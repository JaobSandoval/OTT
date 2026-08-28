import 'package:exel_ott/features/products/domain/product_search_filters.dart';

/// Un intento de búsqueda en catálogo con query y filtros opcionales.
typedef CatalogSearchAttempt = ({
  String query,
  ProductSearchFilters filters,
});

/// Candidato del catálogo que regresó el buscador inteligente de apiCotizadorNew
/// (motor FTS5 + scoring, ya rankeado; ver `candidatos_inteligentes` en la
/// respuesta de `IdentificarProductoPorFoto`).
class IntelligentCandidate {
  const IntelligentCandidate({
    required this.idProducto,
    required this.descripcion,
    required this.marca,
    required this.categoria,
    required this.subcategoria,
  });

  final String idProducto;
  final String descripcion;
  final String marca;
  final String categoria;
  final String subcategoria;

  static IntelligentCandidate fromJson(Map<String, dynamic> json) {
    String str(Object? v) => (v?.toString() ?? '').trim();
    return IntelligentCandidate(
      idProducto: str(json['id_producto']),
      descripcion: str(json['descripcion']),
      marca: str(json['marca']),
      categoria: str(json['categoria']),
      subcategoria: str(json['subcategoria']),
    );
  }
}

class ProductIdentificationResult {
  const ProductIdentificationResult({
    required this.nombre,
    required this.marca,
    required this.sku,
    required this.categoria,
    required this.descripcion,
    required this.keywords,
    required this.confianza,
    this.busquedaSugerida = '',
    this.modeloUsado = '',
    this.imagenesAnalizadas = 1,
    this.candidatosInteligentes = const [],
    this.seleccionadoInteligenteId,
  });

  final String nombre;
  final String marca;
  final String sku;
  final String categoria;
  final String descripcion;
  final List<String> keywords;
  final String busquedaSugerida;

  /// 'alta' | 'media' | 'baja'
  final String confianza;
  final String modeloUsado;
  final int imagenesAnalizadas;

  /// Candidatos ya rankeados por el buscador inteligente (apiCotizadorNew:
  /// FTS5+scoring + validación de relevancia por IA). Vacío si el servicio no
  /// respondió o no está configurado — en ese caso el caller debe caer a
  /// [catalogSearchAttempts] como hacía antes.
  final List<IntelligentCandidate> candidatosInteligentes;

  /// id_producto que la IA de relevancia eligió como el correcto, o null si
  /// ninguno le convenció.
  final String? seleccionadoInteligenteId;

  bool get hasContent =>
      nombre.isNotEmpty ||
      marca.isNotEmpty ||
      sku.isNotEmpty ||
      busquedaSugerida.isNotEmpty ||
      keywords.isNotEmpty;

  String get displayName =>
      nombre.isNotEmpty ? nombre : (sku.isNotEmpty ? sku : 'Producto detectado');

  /// La query más relevante para buscar en el catálogo.
  String get bestSearchQuery {
    final queries = searchQueries;
    return queries.isNotEmpty ? queries.first : '';
  }

  /// Queries de texto ordenadas por relevancia (sin filtros).
  List<String> get searchQueries {
    final seen = <String>{};
    final ordered = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) ordered.add(trimmed);
    }

    if (busquedaSugerida.isNotEmpty) add(busquedaSugerida);
    if (sku.isNotEmpty) add(sku);

    final marcaLower = marca.toLowerCase();
    final nombreLower = nombre.toLowerCase();
    final marcaInNombre =
        marca.isNotEmpty && nombreLower.contains(marcaLower);

    if (marca.isNotEmpty && nombre.isNotEmpty && !marcaInNombre) {
      add('$marca $nombre');
      add('$nombre $marca');
    }

    if (nombre.isNotEmpty) add(nombre);
    if (marca.isNotEmpty && !marcaInNombre) add(marca);

    for (final keyword in keywords) {
      add(keyword);
    }

    return ordered;
  }

  /// Intentos de búsqueda en catálogo: query + filtros (p. ej. id_marca).
  List<CatalogSearchAttempt> get catalogSearchAttempts {
    final seen = <String>{};
    final attempts = <CatalogSearchAttempt>[];

    void addAttempt(String query, ProductSearchFilters filters) {
      final trimmed = query.trim();
      if (trimmed.isEmpty && !filters.hasAny) return;
      final key =
          '${trimmed.toLowerCase()}|${filters.idMarca.toLowerCase()}|'
          '${filters.idCategoria.toLowerCase()}|${filters.idSubcategoria.toLowerCase()}';
      if (!seen.add(key)) return;
      attempts.add((query: trimmed, filters: filters));
    }

    if (sku.isNotEmpty) {
      addAttempt(sku, const ProductSearchFilters());
      if (marca.isNotEmpty) {
        addAttempt(sku, ProductSearchFilters(idMarca: marca));
      }
    }

    if (busquedaSugerida.isNotEmpty) {
      addAttempt(busquedaSugerida, const ProductSearchFilters());
      if (marca.isNotEmpty) {
        addAttempt(busquedaSugerida, ProductSearchFilters(idMarca: marca));
      }
    }

    final marcaLower = marca.toLowerCase();
    final nombreLower = nombre.toLowerCase();
    final marcaInNombre =
        marca.isNotEmpty && nombreLower.contains(marcaLower);

    if (nombre.isNotEmpty && marca.isNotEmpty && !marcaInNombre) {
      addAttempt(nombre, ProductSearchFilters(idMarca: marca));
    }

    for (final query in searchQueries) {
      addAttempt(query, const ProductSearchFilters());
    }

    return attempts;
  }

  static ProductIdentificationResult fromJson(
    Map<String, dynamic> json, {
    String modeloUsado = '',
    int imagenesAnalizadas = 1,
  }) {
    final candidatosRaw = json['candidatos_inteligentes'];
    final seleccionadoRaw = json['seleccionado_inteligente'];

    return ProductIdentificationResult(
      nombre: (json['nombre'] as String? ?? '').trim(),
      marca: (json['marca'] as String? ?? '').trim(),
      sku: (json['sku'] as String? ?? '').trim(),
      categoria: (json['categoria'] as String? ?? '').trim(),
      descripcion: (json['descripcion'] as String? ?? '').trim(),
      busquedaSugerida: (json['busqueda_sugerida'] as String? ?? '').trim(),
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
      candidatosInteligentes: candidatosRaw is List
          ? candidatosRaw
              .whereType<Map>()
              .map((e) => IntelligentCandidate.fromJson(Map<String, dynamic>.from(e)))
              .where((c) => c.idProducto.isNotEmpty)
              .toList()
          : const [],
      seleccionadoInteligenteId: seleccionadoRaw is Map
          ? (seleccionadoRaw['id_producto']?.toString().trim().isNotEmpty ?? false)
              ? seleccionadoRaw['id_producto'].toString().trim()
              : null
          : null,
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
