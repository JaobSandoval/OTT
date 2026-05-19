import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:flutter/material.dart';

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
      setState(() => _error = friendlyErrorMessage(e));
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

    return SafeArea(
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
                      if (AppConfig.useMockApi) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _simulateIncoming,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Simular notificación (mock)'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

