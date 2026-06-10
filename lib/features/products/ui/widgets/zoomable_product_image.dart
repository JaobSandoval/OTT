import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Imagen de producto con pinch-zoom y vista ampliada al tocar.
class ZoomableProductImage extends StatelessWidget {
  const ZoomableProductImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.minScale = 1,
    this.maxScale = 4,
    this.enableFullscreenOnTap = true,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final double minScale;
  final double maxScale;
  final bool enableFullscreenOnTap;
  final Widget Function(BuildContext, Widget child, ImageChunkEvent? progress)?
      loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final image = InteractiveViewer(
      minScale: minScale,
      maxScale: maxScale,
      child: Image.network(
        url,
        fit: fit,
        filterQuality: FilterQuality.medium,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder ??
            (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
      ),
    );

    if (!enableFullscreenOnTap) return image;

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: image,
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 72,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(ctx).top + 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
