import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/features/welcome/data/welcome_banners_repository.dart';
import 'package:exel_ott/features/welcome/domain/welcome_content.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';
import 'package:exel_ott/features/welcome/ui/welcome_banner_navigation.dart';
import 'package:exel_ott/features/welcome/ui/welcome_layout_metrics.dart';
import 'package:exel_ott/features/welcome/ui/welcome_retry_network_image.dart';
import 'package:exel_ott/features/welcome/ui/welcome_promo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  WelcomeScreen({
    super.key,
    required this.auth,
    WelcomeBannersRepository? bannersRepository,
  })  : _bannersRepository = bannersRepository ?? WelcomeBannersRepository();

  final AuthController auth;
  final WelcomeBannersRepository _bannersRepository;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late Future<WelcomeContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget._bannersRepository.loadPreLoginContent();
  }

  void _onBannerTap(String? linkUrl) {
    navigateWelcomeLink(context, linkUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
            Expanded(
              child: FutureBuilder<WelcomeContent>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !(snapshot.data?.hasContent ?? false)) {
                    return _EmptyWelcomeState(
                      topInset: topInset,
                      message: snapshot.hasError
                          ? 'No pudimos cargar el contenido.\nPuedes continuar con el catálogo o iniciar sesión.'
                          : 'Bienvenido a ${AppConfig.appName}',
                    );
                  }

                  final content = snapshot.data!;
                  return _WelcomeScrollContent(
                    topInset: topInset,
                    content: content,
                    onBannerTap: _onBannerTap,
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
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
              child: ListenableBuilder(
                listenable: widget.auth,
                builder: (context, _) {
                  final signedIn = widget.auth.isSignedIn;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        signedIn
                            ? 'Continúa en XLStore con tu cuenta'
                            : 'Explora contenidos y accede a XLStore',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => context.go(
                          signedIn ? '/home/products' : '/login',
                        ),
                        icon: Icon(
                          signedIn
                              ? Icons.storefront_rounded
                              : Icons.login_rounded,
                        ),
                        label: Text(
                          signedIn ? 'Entrar a XLStore' : 'Iniciar sesión',
                        ),
                      ),
                      if (!signedIn) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/catalog'),
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Explorar catálogo sin cuenta'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeScrollContent extends StatelessWidget {
  const _WelcomeScrollContent({
    required this.topInset,
    required this.content,
    required this.onBannerTap,
  });

  final double topInset;
  final WelcomeContent content;
  final void Function(String? linkUrl) onBannerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = WelcomeLayoutMetrics(MediaQuery.sizeOf(context).width);
    final promocionales = content.orderedSquares;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.horizontalPadding,
              topInset + 12,
              metrics.horizontalPadding,
              8,
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/x.png',
                  height: 32,
                  color: AppColors.brandRed,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(width: 10),
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (promocionales.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: WelcomePromoCarousel(
                banners: promocionales,
                metrics: metrics,
                onBannerTap: (banner) => onBannerTap(banner.linkUrl),
              ),
            ),
          ),
        if (content.marcas.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.horizontalPadding,
                16,
                metrics.horizontalPadding,
                6,
              ),
              child: Text(
                'Marcas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: metrics.marcaRowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.horizontalPadding,
                ),
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
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
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
  });

  final double topInset;
  final String message;

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
