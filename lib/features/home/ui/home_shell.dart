import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/permissions/image_scan_permission_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
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

/// Pantalla inicial tras el login.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AppMeshBackground(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          shape: BoxShape.circle,
                          boxShadow: AppDecorations.softShadow,
                        ),
                        child: const Icon(Icons.menu_rounded, size: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset('assets/x.png', height: 36, fit: BoxFit.contain),
                ],
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppDecorations.brandGradient.createShader(bounds),
                child: Text(
                  'Bienvenido',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Accede rápido a tu código y al catálogo de productos.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const AppSectionLabel(text: 'Acciones rápidas'),
              const SizedBox(height: 10),
              _BentoCard(
                gradient: AppDecorations.brandGradient,
                icon: Icons.pin_rounded,
                title: 'Ver código',
                subtitle: 'Tu OTP al instante',
                onTap: () => context.go('/home/otp'),
              ),
              const SizedBox(height: 14),
              _BentoCard(
                gradient: const LinearGradient(
                  colors: [AppColors.brandBlue, Color(0xFF3B4FD9)],
                ),
                icon: Icons.grid_view_rounded,
                title: 'Productos',
                subtitle: 'Explora el catálogo',
                onTap: () => context.go('/home/products'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Gradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Ink(
          height: 120,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandRed.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
