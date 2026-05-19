import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/features/home/ui/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor con menú lateral (datos del cliente, cerrar sesión, actualizar).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.child,
    this.title = 'App XLStore',
  });

  final AuthController auth;
  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: AppDrawer(auth: auth),
      body: child,
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
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Abre el menú lateral para ver tu información o consulta el código de confirmación.',
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
