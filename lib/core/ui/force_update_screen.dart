import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/ui/app_config_block_screen.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:flutter/material.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.appVersion,
    required this.requiredVersion,
  });

  final String appVersion;
  final String requiredVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppConfigBlockScreen(
      icon: Icons.system_update_alt_rounded,
      title: 'Actualización requerida',
      message:
          'Hay una nueva versión disponible. '
          'Actualiza la app para continuar.',
      primaryLabel: 'Actualizar ahora',
      onPrimary: () => openExternalUrl(
        context,
        AppRuntimeEndpoints.instance.storeUpdateUrl,
      ),
      footer: Text(
        'Tu versión: $appVersion · Requerida: $requiredVersion',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
