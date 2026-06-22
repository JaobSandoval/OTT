import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/features/welcome/ui/welcome_layout_metrics.dart';
import 'package:exel_ott/features/welcome/ui/welcome_retry_network_image.dart';
import 'package:flutter/material.dart';

/// Banner promocional con marco de altura fija (todas las imágenes iguales).
class WelcomeAdaptiveBanner extends StatelessWidget {
  const WelcomeAdaptiveBanner({
    super.key,
    required this.imageUrl,
    required this.metrics,
    this.onTap,
  });

  final String imageUrl;
  final WelcomeLayoutMetrics metrics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = metrics.bannerRadius;
    final height = metrics.uniformBannerHeight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: AppDecorations.softCard(radius: radius).copyWith(
            color: AppColors.surfaceElevated,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: WelcomeRetryNetworkImage(
                  key: ValueKey(imageUrl),
                  url: imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
