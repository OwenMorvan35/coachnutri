import 'dart:async';

import 'package:flutter/material.dart';

import 'core/logger.dart';
import 'core/session.dart';
import 'core/session_storage.dart';
import 'theme/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/shell/shell_page.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final sessionController = SessionController();
      // Try to restore cached session before rendering the app
      try {
        final restored = await SessionStorage().load();
        if (restored != null) {
          sessionController.setSession(restored);
        }
      } catch (_) {}
      FlutterError.onError = (details) {
        Logger.e(
          'FLUTTER',
          'Uncaught Flutter error',
          details.exception,
          details.stack,
        );
      };
      runApp(CoachNutriApp(sessionController: sessionController));
    },
    (error, stackTrace) =>
        Logger.e('ZONE', 'Uncaught async error', error, stackTrace),
  );
}

/// Root widget configuring theme, session scope, and navigation.
class CoachNutriApp extends StatelessWidget {
  const CoachNutriApp({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: sessionController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CoachNutri',
        theme: AppTheme.light(),
        home: SessionGate(controller: sessionController),
      ),
    );
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isAuthenticated) {
          return const AuthPage();
        }
        return const ShellPage();
      },
    );
  }
}
