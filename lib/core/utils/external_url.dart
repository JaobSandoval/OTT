import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalUrl(BuildContext context, String? url) async {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) {
    _showError(context, 'Enlace no disponible.');
    return;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    _showError(context, 'Enlace no válido.');
    return;
  }

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showError(context, 'No se pudo abrir el enlace.');
    }
  } on Object {
    if (context.mounted) {
      _showError(context, 'No se pudo abrir el enlace.');
    }
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
