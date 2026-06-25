import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/welcome/ui/welcome_retry_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Carrusel horizontal de productos nuevos (imagen + tap al detalle).
class NewProductsCarousel extends StatelessWidget {
  const NewProductsCarousel({
    super.key,
    required this.productsFuture,
    required this.itemWidth,
    required this.height,
    this.embeddedInShell = false,
    this.catalogOnly = false,
    this.horizontalPadding = 16,
    this.spacing = 10,
    this.radius = 14,
  });

  final Future<List<ProductCard>> productsFuture;
  final double itemWidth;
  final double height;
  final bool embeddedInShell;
  final bool catalogOnly;
  final double horizontalPadding;
  final double spacing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductCard>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: 4,
              separatorBuilder: (context, index) => SizedBox(width: spacing),
              itemBuilder: (context, index) => _NewProductSkeleton(
                width: itemWidth,
                height: height,
                radius: radius,
              ),
            ),
          );
        }

        final products = snapshot.data ?? const [];
        if (products.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: products.length,
            separatorBuilder: (context, index) => SizedBox(width: spacing),
            itemBuilder: (context, index) {
              return _NewProductTile(
                product: products[index],
                width: itemWidth,
                height: height,
                radius: radius,
                embeddedInShell: embeddedInShell,
                catalogOnly: catalogOnly,
              );
            },
          ),
        );
      },
    );
  }
}

class _NewProductTile extends StatelessWidget {
  const _NewProductTile({
    required this.product,
    required this.width,
    required this.height,
    required this.radius,
    required this.embeddedInShell,
    required this.catalogOnly,
  });

  final ProductCard product;
  final double width;
  final double height;
  final double radius;
  final bool embeddedInShell;
  final bool catalogOnly;

  void _openDetail(BuildContext context) {
    final path = catalogOnly || !embeddedInShell
        ? '/catalog/detail/${product.idProducto}'
        : '/home/products/detail/${product.idProducto}';
    context.push(path, extra: product);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.borderLight),
          ),
          padding: const EdgeInsets.all(6),
          child: ColoredBox(
            color: AppColors.cardWhite,
            child: SizedBox.expand(
              child: WelcomeRetryNetworkImage(
                url: product.imageUrl,
                fit: BoxFit.contain,
                showManualRetry: false,
                loadingSize: 22,
                errorIconSize: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProductSkeleton extends StatelessWidget {
  const _NewProductSkeleton({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
