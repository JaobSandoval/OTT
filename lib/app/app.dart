import 'package:exel_ott/app/app_router.dart';
import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/debug/debug_terminal_overlay.dart';
import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/core/notifications/push_notification_service.dart';
import 'package:exel_ott/features/auth/data/auth_api_repository.dart';
import 'package:exel_ott/features/auth/data/auth_exel_repository.dart';
import 'package:exel_ott/features/auth/data/auth_mock_repository.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/otp/data/otp_api_repository.dart';
import 'package:exel_ott/features/otp/data/otp_exel_repository.dart';
import 'package:exel_ott/features/otp/data/otp_mock_repository.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:flutter/material.dart';

class ExelOttApp extends StatefulWidget {
  const ExelOttApp({super.key});

  @override
  State<ExelOttApp> createState() => _ExelOttAppState();
}

class _ExelOttAppState extends State<ExelOttApp> {
  late final SessionStore _sessionStore;
  late final AuthController _authController;
  late final LocalNotificationsService _notifications;

  late final AuthRepository _authRepository;
  late final OtpRepository _otpRepository;
  late final ProductsRepository _productsRepository;

  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore();
    _notifications = LocalNotificationsService();

    _authRepository = AppConfig.useMockApi
        ? AuthMockRepository()
        : AppConfig.useExelAuth
            ? AuthExelRepository(sessionStore: _sessionStore)
            : AuthApiRepository(sessionStore: _sessionStore);

    _otpRepository = AppConfig.useMockApi
        ? OtpMockRepository()
        : AppConfig.useExelAuth
            ? OtpExelRepository(sessionStore: _sessionStore)
            : OtpApiRepository(sessionStore: _sessionStore);

    _productsRepository = ProductsRepository(sessionStore: _sessionStore);

    _authController = AuthController(
      sessionStore: _sessionStore,
      authRepository: _authRepository,
    );

    _appRouter = AppRouter(
      authController: _authController,
      otpRepository: _otpRepository,
      notifications: _notifications,
      productsRepository: _productsRepository,
    );

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notifications.init(
      onNotificationTap: (payload) {
        if (payload == kNotificationPayloadOpenOtp) {
          _appRouter.router.go('/home/otp');
        }
      },
    );
    await PushNotificationService.instance.configure(
      router: _appRouter.router,
      localNotifications: _notifications,
    );
    await _authController.loadFromStorage();
    if (await _notifications.launchedFromOpenOtpTap()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appRouter.router.go('/home/otp');
      });
    }
    PushNotificationService.instance.consumePendingLaunchNavigation();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
    );

    return MaterialApp.router(
      routerConfig: _appRouter.router,
      builder: (context, child) {
        return DebugTerminalOverlay(child: child ?? const SizedBox.shrink());
      },
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
    );
  }
}

