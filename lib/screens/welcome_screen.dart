import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final bool showSkipToLogin;
  const WelcomeScreen({super.key, this.showSkipToLogin = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image / Gradient
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Opacity(
                opacity: 0.8,
                child: Image.network(
                  'https://picsum.photos/1200/2000',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    );
                  },
                ),
              ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.5, 0.9],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    'Elevate Your\nSignature Look.',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.1,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Precision hairstyle consulting powered by AI geometry. Find your perfect cut.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.read<AuthController>().setWelcomeSeen();
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('Get Started'),
                    ),
                  ),
                  if (showSkipToLogin) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Text('Go to Login'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
