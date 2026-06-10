import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.auth,
  });

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final theme = Theme.of(context);
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final config = AppRuntimeEndpoints.instance;

    void openInAppAndClose(String url) {
      Navigator.of(context).pop();
      openInAppUrl(context, url);
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppDecorations.brandGradient,
                borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                boxShadow: AppDecorations.softShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/x.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.displayAppName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (user != null) ...[
                          Text(
                            user.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'v1.0.13',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.pin_outlined,
              label: 'Ver código',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home/otp');
              },
            ),
            _DrawerItem(
              icon: Icons.grid_view_rounded,
              label: 'Productos',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home/products');
              },
            ),
            _DrawerItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Mi carrito',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home/cart');
              },
            ),
            _DrawerItem(
              icon: Icons.language_outlined,
              label: 'Sitio Exel',
              onTap: () => openInAppAndClose(config.urlExel),
            ),
            _DrawerItem(
              icon: Icons.storefront_outlined,
              label: 'XL Store',
              onTap: () => openInAppAndClose(config.urlXlStore),
            ),
            _DrawerItem(
              icon: Icons.system_update_alt_outlined,
              label: 'Actualizar Versión',
              onTap: () => openInAppAndClose(config.storeUpdateUrl),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.brandRed),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await auth.logout();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 8),
              child: Text(
                now,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      onTap: onTap,
    );
  }
}
