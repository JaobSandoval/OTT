import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/features/home/ui/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor con menú lateral y pestañas inferiores (Inicio / Productos).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.child,
    this.title = 'App XLStore',
    this.showBottomNav = true,
    this.bottomNavIndex = 0,
    this.showBackButton = false,
  });

  final AuthController auth;
  final Widget child;
  final String title;
  final bool showBottomNav;
  final int bottomNavIndex;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: showBackButton
            ? [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menú',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ]
            : null,
      ),
      drawer: AppDrawer(auth: auth),
      body: child,
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: bottomNavIndex,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/home');
                  case 1:
                    context.go('/home/products');
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: 'Productos',
                ),
              ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bienvenido',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Usa la pestaña Productos para buscar artículos, o abre el menú lateral para ver tu información.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/home/otp'),
                icon: const Icon(Icons.pin),
                label: const Text('Ver código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
