/// Parámetros al abrir [VisualScanScreen] desde la lente o el buscador.
class VisualScanLaunchArgs {
  const VisualScanLaunchArgs({
    this.photos = const [],
    this.autoAnalyze = false,
    this.barcode,
  });

  final List<String> photos;
  final bool autoAnalyze;
  final String? barcode;
}
