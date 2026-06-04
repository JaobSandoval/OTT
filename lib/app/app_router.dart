import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/auth/ui/login_screen.dart';
import 'package:exel_ott/features/home/ui/home_shell.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:exel_ott/features/otp/ui/otp_screen.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/cart/ui/cart_screen.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/ui/product_detail_screen.dart';
import 'package:exel_ott/features/products/ui/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter({
    required AuthController authController,
    required OtpRepository otpRepository,
    required LocalNotificationsService notifications,
    required ProductsRepository productsRepository,
    required CartRepository cartRepository,
  })  : _authController = authController,
        _otpRepository = otpRepository,
        _notifications = notifications,
        _productsRepository = productsRepository,
        _cartRepository = cartRepository {
    router = GoRouter(
      initialLocation: '/home',
      refreshListenable: _authController,
      redirect: (context, state) {
        final isLoggingIn = state.matchedLocation == '/login';
        final signedIn = _authController.isSignedIn;
        if (!signedIn) {
          return isLoggingIn ? null : '/login';
        }
        if (signedIn && isLoggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(auth: _authController),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            final onHome = path == '/home';
            final onOtp = path.endsWith('/otp');
            final onProducts = path.contains('/products');
            final onDetail = path.contains('/detail/');
            final onCart = path.endsWith('/cart');
            final title = onOtp
                ? 'Código'
                : onCart
                    ? 'Mi carrito'
                    : onDetail
                        ? _productDetailTitle(state)
                        : onProducts
                            ? 'Productos'
                            : '';
            return AppShell(
              auth: _authController,
              title: title,
              showAppBar: !onHome,
              showBottomNav: !onOtp && !onDetail && !onCart,
              bottomNavIndex: onProducts && !onDetail ? 1 : 0,
              showBackButton: onOtp || onDetail || onCart,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
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
                  path: 'products',
                  builder: (context, state) => ProductsScreen(
                    productsRepository: _productsRepository,
                    cartRepository: _cartRepository,
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
