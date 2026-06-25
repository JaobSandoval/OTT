import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/features/welcome/domain/welcome_banner.dart';
import 'package:exel_ott/features/welcome/ui/welcome_adaptive_banner.dart';
import 'package:exel_ott/features/welcome/ui/welcome_layout_metrics.dart';
import 'package:flutter/material.dart';

class WelcomePromoCarousel extends StatefulWidget {
  const WelcomePromoCarousel({
    super.key,
    required this.banners,
    required this.metrics,
    required this.onBannerTap,
  });

  final List<WelcomeBanner> banners;
  final WelcomeLayoutMetrics metrics;
  final void Function(WelcomeBanner banner) onBannerTap;

  @override
  State<WelcomePromoCarousel> createState() => _WelcomePromoCarouselState();
}

class _WelcomePromoCarouselState extends State<WelcomePromoCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    if (widget.banners.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.metrics.horizontalPadding),
        child: WelcomeAdaptiveBanner(
          imageUrl: widget.banners.first.imageUrl,
          metrics: widget.metrics,
          onTap: widget.banners.first.hasLink
              ? () => widget.onBannerTap(widget.banners.first)
              : null,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.metrics.uniformBannerHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.metrics.gridSpacing / 2,
                ),
                child: WelcomeAdaptiveBanner(
                  imageUrl: banner.imageUrl,
                  metrics: widget.metrics,
                  onTap: banner.hasLink
                      ? () => widget.onBannerTap(banner)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final active = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brandRed
                    : AppColors.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}
