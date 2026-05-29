import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final color = Theme.of(context).colorScheme.primary;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final config = AppRuntimeEndpoints.instance;

    Future<void> openAndClose(String? url) async {
      Navigator.of(context).pop();
      await openExternalUrl(context, url);
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: color,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/x.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.displayAppName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (user != null) ...[
                        Text(
                          user.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.regions,
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Versión 1.0.8',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pin),
            title: const Text('Ver código'),
            onTap: () {
              Navigator.of(context).pop();
              context.go('/home/otp');
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Sitio Exel'),
            onTap: () => openAndClose(config.urlExel),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('XL Store'),
            onTap: () => openAndClose(config.urlXlStore),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar Sesión'),
            onTap: () async {
              Navigator.of(context).pop();
              await auth.logout();
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Actualizar Versión'),
            onTap: () => openAndClose(config.storeUpdateUrl),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              now,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
