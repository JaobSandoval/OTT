class QuoteLine {
  const QuoteLine({
    required this.texto,
    this.sku = '',
    this.cantidad = 1,
    this.notas = '',
  });

  final String texto;
  final String sku;
  final int cantidad;
  final String notas;

  String get searchQuery {
    final code = sku.trim();
    if (code.isNotEmpty) return code;
    return texto.trim();
  }

  QuoteLine copyWith({
    String? texto,
    String? sku,
    int? cantidad,
    String? notas,
  }) {
    return QuoteLine(
      texto: texto ?? this.texto,
      sku: sku ?? this.sku,
      cantidad: cantidad ?? this.cantidad,
      notas: notas ?? this.notas,
    );
  }
}

class QuoteExtractionResult {
  const QuoteExtractionResult({
    required this.lineas,
    this.observaciones = '',
  });

  final List<QuoteLine> lineas;
  final String observaciones;
}
