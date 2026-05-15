import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.otpRepository,
    required this.notifications,
  });

  final OtpRepository otpRepository;
  final LocalNotificationsService notifications;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool _loading = false;
  OtpCode? _otp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final otp = await widget.otpRepository.fetchCurrent();
      setState(() => _otp = otp);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _simulateIncoming() async {
    final otp = await widget.otpRepository.rotateMock();
    await widget.notifications.showOtpAvailableNotification(
      title: 'Código disponible',
      body: 'Toca para abrir la app y ver el código.',
    );
    if (!mounted) return;
    setState(() => _otp = otp);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = _otp?.expiresAt;
    final expiresText =
        expires == null ? '—' : DateFormat('HH:mm:ss').format(expires.toLocal());

    return Scaffold(
      appBar: AppBar(title: const Text('Código')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _otp?.code ?? 'Sin código',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Expira: $expiresText'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _loading ? null : _refresh,
                        icon: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _simulateIncoming,
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Simular notificación (mock)'),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Las notificaciones push usan Firebase (FCM). '
                'En primer plano Android muestra aviso local; al tocar, abre esta pantalla.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

