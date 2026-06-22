/// Medidas responsivas para la pantalla de bienvenida (marcas + promocionales).
class WelcomeLayoutMetrics {
  WelcomeLayoutMetrics(double screenWidth)
      : width = screenWidth,
        horizontalPadding = screenWidth < 360 ? 14.0 : 16.0,
        marcaSize = screenWidth < 360 ? 72.0 : 84.0,
        gridSpacing = screenWidth < 360 ? 8.0 : 10.0,
        bannerRadius = 14.0;

  final double width;
  final double horizontalPadding;
  final double marcaSize;
  final double gridSpacing;
  final double bannerRadius;

  double get contentWidth => width - (horizontalPadding * 2);

  /// Fila horizontal de logos (debajo de banners).
  double get marcaRowHeight => marcaSize + 20;

  /// Alto fijo del carrusel: todas las imágenes comparten el mismo marco.
  double get uniformBannerHeight => contentWidth * 0.72;
}
