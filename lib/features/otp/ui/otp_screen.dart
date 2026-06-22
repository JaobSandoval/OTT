import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseMonitoringService.instance.logOtpRequested();
      final otp = await widget.otpRepository.fetchCurrent();
      if (!mounted) return;
      setState(() => _otp = otp);
      if (otp != null && otp.code.isNotEmpty) {
        await FirebaseMonitoringService.instance.logOtpVerified();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _simulateIncoming() async {
    final otp = await widget.otpRepository.rotateMock();
    if (!mounted) return;
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
    final code = _otp?.code;

    return AppMeshBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppGradientBorderCard(
                          innerPadding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 36,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'CÓDIGO OTP',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: CircularProgressIndicator(),
                                )
                              else
                                Text(
                                  code ?? '——',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 8,
                                    color: code != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _refresh,
                            icon: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text('Actualizar'),
                          ),
                        ),
                        if (AppConfig.useMockApi) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _simulateIncoming,
                              icon: const Icon(Icons.notifications_active_outlined),
                              label: const Text('Simular notificación (mock)'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
