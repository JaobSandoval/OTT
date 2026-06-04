import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppDecorations {
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 28.0;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandRed, AppColors.brandBlue],
  );

  static const brandGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x14D12027),
      Color(0x140019D1),
    ],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get navShadow => [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.1),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  static BoxDecoration softCard({Color? color, double radius = radiusLg}) =>
      BoxDecoration(
        color: color ?? AppColors.cardWhite,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow,
      );

  static BoxDecoration gradientRing({double radius = radiusXl}) => BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(radius),
      );
}
