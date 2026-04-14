import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Premium system overlays for a clean dark brand look.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController()..initialize(),
      child: const IvexApp(),
    ),
  );
}

class IvexApp extends StatelessWidget {
  const IvexApp({super.key});

  // IVEX Design Tokens - Dark
  static const Color darkBlack = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF111111);
  static const Color darkAccent = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFFF3F3F3);
  static const Color darkMuted = Color(0xFF888888);

  // IVEX Design Tokens - Light
  static const Color lightWhite = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9F9FB);
  static const Color lightAccent = Color(0xFF000000);
  static const Color lightText = Color(0xFF171717);
  static const Color lightMuted = Color(0xFF71717A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IVEX',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightAccent,
        surface: lightSurface,
        onSurface: lightText,
      ),
      scaffoldBackgroundColor: lightWhite,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: lightText,
        displayColor: lightText,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(lightAccent, lightWhite),
      outlinedButtonTheme: _outlinedButtonTheme(lightText, const Color(0xFFE4E4E7)),
      inputDecorationTheme: _inputDecorationTheme(lightSurface, lightMuted, lightAccent),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        secondary: darkAccent,
        surface: darkSurface,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: darkBlack,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(darkAccent, darkBlack),
      outlinedButtonTheme: _outlinedButtonTheme(darkText, const Color(0xFF27272A)),
      inputDecorationTheme: _inputDecorationTheme(darkSurface, darkMuted, darkAccent),
    );
  }

  ElevatedButtonThemeData _elevatedButtonTheme(Color bg, Color fg) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecorationTheme _inputDecorationTheme(Color fill, Color muted, Color accent) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.inter(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );
  }
}
