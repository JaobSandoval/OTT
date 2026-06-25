/// Medidas responsivas para la pantalla de bienvenida (marcas + promocionales).
class WelcomeLayoutMetrics {
  WelcomeLayoutMetrics(
    double screenWidth, {
    double? viewportHeight,
    double topInset = 0,
    double bottomReserve = 0,
    bool hasBanners = true,
    bool hasMarcas = true,
    bool hasProducts = true,
    bool compact = false,
  })  : width = screenWidth,
        horizontalPadding = screenWidth < 360 ? 14.0 : 16.0,
        gridSpacing = screenWidth < 360 ? 8.0 : 10.0,
        bannerRadius = 14.0,
        sectionTopGap = compact ? 10.0 : 14.0,
        headerTopGap = compact ? 8.0 : 12.0,
        headerBottomGap = compact ? 4.0 : 8.0 {
    contentWidth = width - (horizontalPadding * 2);

    if (viewportHeight != null && viewportHeight > 0) {
      _applyViewportFit(
        viewportHeight: viewportHeight,
        topInset: topInset,
        bottomReserve: bottomReserve,
        hasBanners: hasBanners,
        hasMarcas: hasMarcas,
        hasProducts: hasProducts,
        compact: compact,
      );
    } else {
      _applyScrollDefaults(compact: compact);
    }
  }

  final double width;
  final double horizontalPadding;
  final double gridSpacing;
  final double bannerRadius;
  final double sectionTopGap;
  final double headerTopGap;
  final double headerBottomGap;

  late final double contentWidth;
  late final double marcaSize;
  late final double marcaRowHeight;
  late final double newProductItemWidth;
  late final double newProductsRowHeight;
  late final double uniformBannerHeight;
  late final double headerLogoHeight;

  void _applyScrollDefaults({required bool compact}) {
    headerLogoHeight = compact ? 30.0 : 32.0;
    marcaSize = compact
        ? (width < 360 ? 64.0 : 72.0)
        : (width < 360 ? 72.0 : 84.0);
    marcaRowHeight = marcaSize + (compact ? 12.0 : 20.0);
    newProductItemWidth = _defaultProductWidth(compact: compact);
    newProductsRowHeight = newProductItemWidth * 1.06;
    uniformBannerHeight = contentWidth * (compact ? 0.58 : 0.66);
  }

  void _applyViewportFit({
    required double viewportHeight,
    required double topInset,
    required double bottomReserve,
    required bool hasBanners,
    required bool hasMarcas,
    required bool hasProducts,
    required bool compact,
  }) {
    headerLogoHeight = compact ? 30.0 : 32.0;

    final headerHeight =
        topInset + headerTopGap + headerLogoHeight + headerBottomGap + 8;
    const sectionTitleHeight = 26.0;
    const bannerDotsHeight = 18.0;
    const bannerTopPad = 6.0;

    var overhead = bottomReserve + headerHeight;
    if (hasBanners) overhead += bannerTopPad + bannerDotsHeight;
    if (hasMarcas) overhead += sectionTopGap + sectionTitleHeight;
    if (hasProducts) overhead += sectionTopGap + sectionTitleHeight;

    newProductItemWidth = _defaultProductWidth(compact: compact);
    newProductsRowHeight = newProductItemWidth * 1.06;

    if (hasProducts) overhead += newProductsRowHeight;

    final flexSpace = (viewportHeight - overhead).clamp(80.0, viewportHeight);

    if (hasProducts) {
      if (hasBanners && hasMarcas) {
        uniformBannerHeight =
            (flexSpace * 0.70).clamp(96.0, contentWidth * 0.56);
        marcaSize = (flexSpace * 0.30 - (compact ? 10.0 : 14.0))
            .clamp(compact ? 52.0 : 56.0, 72.0);
      } else if (hasBanners) {
        uniformBannerHeight = flexSpace.clamp(96.0, contentWidth * 0.58);
        marcaSize = 0;
      } else if (hasMarcas) {
        uniformBannerHeight = 0;
        marcaSize = flexSpace.clamp(compact ? 54.0 : 58.0, 76.0);
      } else {
        uniformBannerHeight = 0;
        marcaSize = 0;
      }
    } else if (hasBanners && hasMarcas) {
      uniformBannerHeight =
          (flexSpace * 0.68).clamp(96.0, contentWidth * 0.60);
      marcaSize =
          (flexSpace * 0.24).clamp(compact ? 54.0 : 58.0, 76.0);
    } else if (hasBanners) {
      uniformBannerHeight = flexSpace.clamp(96.0, contentWidth * 0.64);
      marcaSize = 0;
    } else if (hasMarcas) {
      uniformBannerHeight = 0;
      marcaSize = flexSpace.clamp(compact ? 58.0 : 62.0, 84.0);
    } else {
      uniformBannerHeight = 0;
      marcaSize = 0;
    }

    marcaRowHeight = marcaSize + (compact ? 10.0 : 14.0);
  }

  double _defaultProductWidth({required bool compact}) {
    if (width < 360) return compact ? 118.0 : 128.0;
    return (contentWidth * (compact ? 0.40 : 0.42)).clamp(128.0, 158.0);
  }
}
