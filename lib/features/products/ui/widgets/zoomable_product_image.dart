import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Imagen de producto con pinch-zoom y vista ampliada al tocar.
class ZoomableProductImage extends StatelessWidget {
  const ZoomableProductImage({
    super.key,
    required this.url,
    this.galleryUrls,
    this.galleryIndex = 0,
    this.fit = BoxFit.contain,
    this.minScale = 1,
    this.maxScale = 4,
    this.enablePinchZoom = true,
    this.enableFullscreenOnTap = true,
    this.highQuality = false,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final List<String>? galleryUrls;
  final int galleryIndex;
  final BoxFit fit;
  final double minScale;
  final double maxScale;
  final bool enablePinchZoom;
  final bool enableFullscreenOnTap;
  final bool highQuality;
  final Widget Function(BuildContext, Widget child, ImageChunkEvent? progress)?
      loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  List<String> get _fullscreenUrls {
    if (galleryUrls != null && galleryUrls!.isNotEmpty) {
      return galleryUrls!;
    }
    return [url];
  }

  int get _fullscreenInitialIndex {
    final urls = _fullscreenUrls;
    if (galleryUrls != null && galleryUrls!.isNotEmpty) {
      return galleryIndex.clamp(0, urls.length - 1);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        int? cacheWidth;
        int? cacheHeight;
        if (highQuality &&
            constraints.maxWidth.isFinite &&
            constraints.maxHeight.isFinite &&
            constraints.maxWidth > 0 &&
            constraints.maxHeight > 0) {
          cacheWidth = (constraints.maxWidth * dpr).round();
          cacheHeight = (constraints.maxHeight * dpr).round();
        }

        final image = Image.network(
          url,
          fit: fit,
          filterQuality:
              highQuality ? FilterQuality.high : FilterQuality.medium,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder ??
              (context, error, stackTrace) => Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
        );

        final Widget content = enablePinchZoom
            ? InteractiveViewer(
                minScale: minScale,
                maxScale: maxScale,
                child: image,
              )
            : image;

        if (!enableFullscreenOnTap) return content;

        return GestureDetector(
          onTap: () => _openFullscreen(context),
          child: content,
        );
      },
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) {
        return _FullscreenImageViewer(
          urls: _fullscreenUrls,
          initialIndex: _fullscreenInitialIndex,
        );
      },
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  bool get _hasMultiple => widget.urls.length > 1;

  void _goTo(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.urls.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              key: ValueKey(widget.urls[_index]),
              minScale: 0.5,
              maxScale: 6,
              child: Image.network(
                widget.urls[_index],
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 72,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (_hasMultiple && _index > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrowButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Foto anterior',
                  onPressed: () => _goTo(-1),
                ),
              ),
            ),
          if (_hasMultiple && _index < widget.urls.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrowButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Foto siguiente',
                  onPressed: () => _goTo(1),
                ),
              ),
            ),
          Positioned(
            top: topPadding + 8,
            right: 8,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (_hasMultiple)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavArrowButton extends StatelessWidget {
  const _NavArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.borderLight),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textPrimary, size: 32),
      ),
    );
  }
}
