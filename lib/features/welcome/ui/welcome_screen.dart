import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/welcome/data/welcome_banners_repository.dart';
import 'package:exel_ott/features/welcome/domain/welcome_content.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';
import 'package:exel_ott/features/welcome/ui/welcome_banner_navigation.dart';
import 'package:exel_ott/features/welcome/ui/welcome_layout_metrics.dart';
import 'package:exel_ott/features/welcome/ui/welcome_retry_network_image.dart';
import 'package:exel_ott/features/products/ui/widgets/new_products_carousel.dart';
import 'package:exel_ott/features/welcome/ui/welcome_promo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  WelcomeScreen({
    super.key,
    required this.auth,
    this.embeddedInShell = false,
    ProductsRepository? productsRepository,
    WelcomeBannersRepository? bannersRepository,
  })  : _productsRepository = productsRepository,
        _bannersRepository = bannersRepository ?? WelcomeBannersRepository();

  final AuthController auth;
  final bool embeddedInShell;
  final ProductsRepository? _productsRepository;
  final WelcomeBannersRepository _bannersRepository;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late Future<WelcomeContent> _contentFuture;
  Future<List<ProductCard>>? _newProductsFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget._bannersRepository.loadPreLoginContent();
    final repo = widget._productsRepository;
    if (repo != null) {
      _newProductsFuture = repo.fetchNewProducts();
    }
  }

  void _onBannerTap(String? linkUrl) {
    navigateWelcomeLink(context, linkUrl);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final embedded = widget.embeddedInShell;

    final body = FutureBuilder<WelcomeContent>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !(snapshot.data?.hasContent ?? false)) {
          return _EmptyWelcomeState(
            topInset: topInset,
            embeddedInShell: embedded,
            message: snapshot.hasError
                ? embedded
                    ? 'No pudimos cargar el contenido.\nUsa el menú para explorar XLStore.'
                    : 'No pudimos cargar el contenido.\nPuedes continuar con el catálogo o iniciar sesión.'
                : 'Bienvenido a ${AppConfig.appName}',
          );
        }

        final content = snapshot.data!;
        return _WelcomeBodyContent(
          topInset: topInset,
          bottomReserve: embedded ? bottomInset + 88.0 : 0,
          content: content,
          embeddedInShell: embedded,
          compact: true,
          newProductsFuture: _newProductsFuture,
          onBannerTap: _onBannerTap,
        );
      },
    );

    if (embedded) {
      return body;
    }

    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        if (!widget.auth.initialized || widget.auth.isSignedIn) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildPublicWelcomeScaffold(
          body: body,
          bottomInset: bottomInset,
        );
      },
    );
  }

  Widget _buildPublicWelcomeScaffold({
    required Widget body,
    required double bottomInset,
  }) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explora contenidos y accede a XLStore',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/catalog'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Explorar catálogo sin cuenta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBodyContent extends StatelessWidget {
  const _WelcomeBodyContent({
    required this.topInset,
    required this.bottomReserve,
    required this.content,
    required this.embeddedInShell,
    required this.compact,
    required this.newProductsFuture,
    required this.onBannerTap,
  });

  final double topInset;
  final double bottomReserve;
  final WelcomeContent content;
  final bool embeddedInShell;
  final bool compact;
  final Future<List<ProductCard>>? newProductsFuture;
  final void Function(String? linkUrl) onBannerTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final promocionales = content.orderedSquares;
        final hasMarcas = content.marcas.isNotEmpty;
        final hasProducts = newProductsFuture != null;
        final metrics = WelcomeLayoutMetrics(
          constraints.maxWidth,
          viewportHeight: constraints.maxHeight,
          topInset: topInset,
          bottomReserve: bottomReserve,
          hasBanners: promocionales.isNotEmpty,
          hasMarcas: hasMarcas,
          hasProducts: hasProducts,
          compact: compact,
        );
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WelcomeHeader(
              topInset: topInset,
              metrics: metrics,
              embeddedInShell: embeddedInShell,
            ),
            if (promocionales.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: metrics.sectionTopGap - 4),
                child: WelcomePromoCarousel(
                  banners: promocionales,
                  metrics: metrics,
                  onBannerTap: (banner) => onBannerTap(banner.linkUrl),
                ),
              ),
            if (hasMarcas) ...[
              _SectionTitle(
                label: 'Marcas',
                metrics: metrics,
                theme: theme,
              ),
              _MarcasRow(content: content, metrics: metrics),
            ],
            if (hasProducts) ...[
              _SectionTitle(
                label: 'Productos nuevos',
                metrics: metrics,
                theme: theme,
              ),
              NewProductsCarousel(
                productsFuture: newProductsFuture!,
                itemWidth: metrics.newProductItemWidth,
                height: metrics.newProductsRowHeight,
                embeddedInShell: embeddedInShell,
                horizontalPadding: metrics.horizontalPadding,
                spacing: metrics.gridSpacing,
                radius: metrics.bannerRadius,
              ),
              const Spacer(),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.metrics,
    required this.theme,
  });

  final String label;
  final WelcomeLayoutMetrics metrics;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.horizontalPadding,
        metrics.sectionTopGap,
        metrics.horizontalPadding,
        4,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.topInset,
    required this.metrics,
    required this.embeddedInShell,
  });

  final double topInset;
  final WelcomeLayoutMetrics metrics;
  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.horizontalPadding,
        topInset + metrics.headerTopGap,
        metrics.horizontalPadding,
        metrics.headerBottomGap,
      ),
      child: Row(
        children: [
          if (embeddedInShell)
            Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_rounded, size: 18),
                ),
              ),
            ),
          if (embeddedInShell) const SizedBox(width: 4),
          Image.asset(
            'assets/x.png',
            height: metrics.headerLogoHeight,
            color: AppColors.brandRed,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 8),
          Text(
            AppConfig.appName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (embeddedInShell) const Spacer(),
        ],
      ),
    );
  }
}

class _MarcasRow extends StatelessWidget {
  const _MarcasRow({
    required this.content,
    required this.metrics,
  });

  final WelcomeContent content;
  final WelcomeLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: metrics.marcaRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
        itemCount: content.marcas.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: metrics.gridSpacing + 4),
        itemBuilder: (context, index) {
          final marca = content.marcas[index];
          return _MarcaChip(
            marca: marca,
            size: metrics.marcaSize,
            onTap: marca.hasLink
                ? () => navigateWelcomeMarca(context, marca)
                : null,
          );
        },
      ),
    );
  }
}

class _MarcaChip extends StatelessWidget {
  const _MarcaChip({
    required this.marca,
    required this.size,
    this.onTap,
  });

  final WelcomeMarca marca;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderLight),
          ),
          padding: EdgeInsets.all(size * 0.12),
          child: WelcomeRetryNetworkImage(
            url: marca.imageUrl,
            fit: BoxFit.contain,
            loadingSize: size * 0.32,
            errorIconSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

class _EmptyWelcomeState extends StatelessWidget {
  const _EmptyWelcomeState({
    required this.topInset,
    required this.message,
    this.embeddedInShell = false,
  });

  final double topInset;
  final String message;
  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
      decoration: const BoxDecoration(
        gradient: AppDecorations.brandGradient,
      ),
      child: Column(
        children: [
          if (embeddedInShell)
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (ctx) => IconButton(
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Image.asset(
            'assets/x.png',
            height: 72,
            fit: BoxFit.contain,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(height: 16),
          Text(
            AppConfig.appName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
