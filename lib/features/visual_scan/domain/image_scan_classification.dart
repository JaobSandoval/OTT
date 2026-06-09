enum ImageScanType { producto, documentoCotizacion }

class ImageScanClassification {
  const ImageScanClassification({
    required this.tipo,
    required this.confianza,
    required this.razon,
    required this.modeloUsado,
  });

  final ImageScanType tipo;
  final String confianza;
  final String razon;
  final String modeloUsado;

  bool get isProducto => tipo == ImageScanType.producto;
  bool get isDocumento => tipo == ImageScanType.documentoCotizacion;

  static ImageScanClassification fromJson(Map<String, dynamic> json) {
    final rawTipo = (json['tipo'] as String? ?? '').trim().toLowerCase();
    final tipo = rawTipo == 'documento_cotizacion'
        ? ImageScanType.documentoCotizacion
        : ImageScanType.producto;

    return ImageScanClassification(
      tipo: tipo,
      confianza: (json['confianza'] as String? ?? 'media').trim().toLowerCase(),
      razon: (json['razon'] as String? ?? '').trim(),
      modeloUsado: (json['modelo_usado'] as String? ?? '').trim(),
    );
  }
}
