import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, child) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (auth.isAuthenticated) {
          return const HomeScreen();
        }
        if (!auth.hasSeenWelcome) {
          return const WelcomeScreen();
        }
        return const WelcomeScreen(showSkipToLogin: false);
      },
    );
  }
}
