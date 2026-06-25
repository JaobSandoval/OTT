import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/permissions/image_scan_permission_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/features/home/ui/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor con menú lateral y pestañas inferiores (Inicio / Productos).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.imageScanPermission,
    required this.child,
    this.title = '',
    this.showAppBar = true,
    this.showBottomNav = true,
    this.bottomNavIndex = 0,
    this.showBackButton = false,
  });

  final AuthController auth;
  final ImageScanPermissionService imageScanPermission;
  final Widget child;
  final String title;
  final bool showAppBar;
  final bool showBottomNav;
  final int bottomNavIndex;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showNav = showBottomNav && !keyboardOpen;

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      extendBody: showNav,
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => context.pop(),
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Mi carrito',
                  onPressed: () => context.push('/home/cart'),
                ),
                if (showBackButton)
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menú',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
              ],
            )
          : null,
      drawer: AppDrawer(
        auth: auth,
      ),
      body: child,
      bottomNavigationBar: showNav
          ? AppFloatingNavBar(
              selectedIndex: bottomNavIndex,
              onSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/home');
                  case 1:
                    context.go('/home/products');
                }
              },
            )
          : null,
    );
  }
}
