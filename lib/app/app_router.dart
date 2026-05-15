import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/features/auth/ui/login_screen.dart';
import 'package:exel_ott/features/home/ui/home_shell.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:exel_ott/features/otp/ui/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter({
    required AuthController authController,
    required OtpRepository otpRepository,
    required LocalNotificationsService notifications,
  })  : _authController = authController,
        _otpRepository = otpRepository,
        _notifications = notifications {
    router = GoRouter(
      initialLocation: '/home',
      refreshListenable: _authController,
      redirect: (context, state) {
        final isLoggingIn = state.matchedLocation == '/login';
        final signedIn = _authController.isSignedIn;
        if (!signedIn) {
          return isLoggingIn ? null : '/login';
        }
        if (signedIn && isLoggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(auth: _authController),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => HomeShell(
            auth: _authController,
            otpRepository: _otpRepository,
            notifications: _notifications,
          ),
          routes: [
            GoRoute(
              path: 'otp',
              builder: (context, state) => OtpScreen(
                otpRepository: _otpRepository,
                notifications: _notifications,
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(state.error.toString())),
      ),
    );
  }

  final AuthController _authController;
  final OtpRepository _otpRepository;
  final LocalNotificationsService _notifications;

  late final GoRouter router;
}

