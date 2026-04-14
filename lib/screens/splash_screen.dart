import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final accent = isDark ? Colors.white : Colors.black;
    final muted = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -170,
            right: -130,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    children: [
                      const Spacer(),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.auto_awesome,
                                  color: accent,
                                  size: 80,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'IVEX',
                              style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 7,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Own your signature look.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                letterSpacing: 0.2,
                                color: muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Developed by Yash Italiya',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
