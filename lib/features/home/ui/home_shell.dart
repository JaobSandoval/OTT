import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/home/ui/widgets/app_drawer.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.otpRepository,
    required this.notifications,
  });

  final AuthController auth;
  final OtpRepository otpRepository;
  final LocalNotificationsService notifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _PlaceholderPage(
        title: 'Sucursal',
        subtitle: 'Pantalla lista para conectar datos.',
        primaryAction: FilledButton(
          onPressed: () => context.go('/home/otp'),
          child: const Text('Ver código'),
        ),
      ),
      const _PlaceholderPage(title: 'División', subtitle: 'Pendiente'),
      const _PlaceholderPage(title: 'Marcas', subtitle: 'Pendiente'),
      const _PlaceholderPage(title: 'Bitácora', subtitle: 'Pendiente'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ventas Exel')),
      drawer: AppDrawer(auth: widget.auth),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Sucursal'),
          NavigationDestination(icon: Icon(Icons.apartment), label: 'División'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Marcas'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Bitácora'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.subtitle,
    this.primaryAction,
  });

  final String title;
  final String subtitle;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (primaryAction != null) Center(child: primaryAction),
            ],
          ),
        ),
      ),
    );
  }
}

