import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/permissions/image_scan_permission_service.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/auth/ui/login_screen.dart';
import 'package:exel_ott/core/ui/in_app_webview_screen.dart';
import 'package:exel_ott/features/home/ui/home_shell.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:exel_ott/features/otp/ui/otp_screen.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/cart/ui/cart_screen.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/ui/product_detail_screen.dart';
import 'package:exel_ott/features/products/ui/products_screen.dart';
import 'package:exel_ott/features/visual_scan/data/visual_scan_repository.dart';
import 'package:exel_ott/features/visual_scan/domain/visual_scan_launch_args.dart';
import 'package:exel_ott/features/visual_scan/ui/visual_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  AppRouter({
    required AuthController authController,
    required OtpRepository otpRepository,
    required LocalNotificationsService notifications,
    required ProductsRepository productsRepository,
    required CartRepository cartRepository,
    required VisualScanRepository visualScanRepository,
    required ImageScanPermissionService imageScanPermissionService,
  })  : _authController = authController,
        _otpRepository = otpRepository,
        _notifications = notifications,
        _productsRepository = productsRepository,
        _cartRepository = cartRepository,
        _visualScanRepository = visualScanRepository,
        _imageScanPermissionService = imageScanPermissionService {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      refreshListenable: _authController,
      redirect: (context, state) {
        final path = state.uri.path;
        final isLoggingIn = path == '/login';
        final isWeb = path == '/web';
        final signedIn = _authController.isSignedIn;
        if (!signedIn) {
          if (isLoggingIn || isWeb) return null;
          return '/login';
        }
        if (signedIn && isLoggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(auth: _authController),
        ),
        GoRoute(
          path: '/web',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final encoded = state.uri.queryParameters['url'] ?? '';
            final url = Uri.decodeComponent(encoded);
            return InAppWebViewScreen(initialUrl: url);
          },
        ),
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) {
            final path = state.uri.path;
            final onHome = path == '/home';
            final onOtp = path.endsWith('/otp');
            final onProducts = path.contains('/products');
            final onDetail = path.contains('/detail/');
            final onCart = path.endsWith('/cart');
            final onVisualScan = path.endsWith('/visual-scan')
                || path.endsWith('/quote-photo')
                || path.endsWith('/product-photo-search');
            final title = onOtp
                ? 'Código'
                : onCart
                    ? 'Mi carrito'
                    : onVisualScan
                        ? 'Búsqueda visual'
                    : onDetail
                        ? _productDetailTitle(state)
                        : onProducts
                            ? 'Productos'
                            : '';
            return AppShell(
              auth: _authController,
              imageScanPermission: _imageScanPermissionService,
              title: title,
              showAppBar: !onHome,
              showBottomNav: !onOtp && !onDetail && !onCart && !onVisualScan,
              bottomNavIndex: onProducts && !onDetail ? 1 : 0,
              showBackButton: onOtp || onDetail || onCart || onVisualScan,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => HomeScreen(),
              routes: [
                GoRoute(
                  path: 'otp',
                  builder: (context, state) => OtpScreen(
                    otpRepository: _otpRepository,
                    notifications: _notifications,
                  ),
                ),
                GoRoute(
                  path: 'cart',
                  builder: (context, state) => CartScreen(
                    repository: _cartRepository,
                  ),
                ),
                GoRoute(
                  path: 'visual-scan',
                  builder: (context, state) => ListenableBuilder(
                    listenable: _imageScanPermissionService,
                    builder: (context, _) {
                      if (!_imageScanPermissionService.loaded) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final launch = state.extra is VisualScanLaunchArgs
                          ? state.extra! as VisualScanLaunchArgs
                          : const VisualScanLaunchArgs();
                      return VisualScanScreen(
                        repository: _visualScanRepository,
                        allowPhotoCapture:
                            _imageScanPermissionService.imageScanEnabled,
                        initialPhotos: launch.photos,
                        autoAnalyze: launch.autoAnalyze,
                        initialBarcode: launch.barcode,
                      );
                    },
                  ),
                ),
                GoRoute(
                  path: 'quote-photo',
                  redirect: (context, state) => '/home/visual-scan',
                ),
                GoRoute(
                  path: 'product-photo-search',
                  redirect: (context, state) => '/home/visual-scan',
                ),
                GoRoute(
                  path: 'products',
                  builder: (context, state) => ProductsScreen(
                    productsRepository: _productsRepository,
                    cartRepository: _cartRepository,
                    imageScanPermission: _imageScanPermissionService,
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail/:idProducto',
                      builder: (context, state) {
                        final initial = state.extra;
                        return ProductDetailScreen(
                          idProducto:
                              state.pathParameters['idProducto'] ?? '',
                          repository: _productsRepository,
                          cartRepository: _cartRepository,
                          initialProduct: initial is ProductCard
                              ? initial
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(state.error.toString())),
      ),
    );
  }

  final AuthController _authController;
  final OtpRepository _otpRepository;
  final LocalNotificationsService _notifications;
  final ProductsRepository _productsRepository;
  final CartRepository _cartRepository;
  final VisualScanRepository _visualScanRepository;
  final ImageScanPermissionService _imageScanPermissionService;

  late final GoRouter router;

  static String _productDetailTitle(GoRouterState state) {
    final extra = state.extra;
    if (extra is ProductCard) {
      if (extra.descripcion.isNotEmpty) return extra.descripcion;
      if (extra.marca.isNotEmpty) return extra.marca;
      return extra.idProducto;
    }
    final id = state.pathParameters['idProducto'];
    if (id != null && id.isNotEmpty) return id;
    return 'Detalle';
  }
}

