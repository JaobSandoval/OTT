import 'package:exel_ott/core/ui/app_config_block_screen.dart';
import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.message,
    required this.onReload,
    this.isReloading = false,
  });

  final String message;
  final VoidCallback onReload;
  final bool isReloading;

  @override
  Widget build(BuildContext context) {
    return AppConfigBlockScreen(
      icon: Icons.construction_rounded,
      title: 'En mantenimiento',
      message: message,
      primaryLabel: 'Reintentar',
      primaryLoading: isReloading,
      onPrimary: onReload,
    );
  }
}
