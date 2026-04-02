import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52E0);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color background = Color(0xFF0E0E1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF252540);
  static const Color onSurface = Color(0xFFE0E0F0);
  static const Color onSurfaceMuted = Color(0xFF8888AA);
  static const Color divider = Color(0xFF2A2A45);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ECDC4);
  static const Color warning = Color(0xFFFFD93D);

  // Message bubble colors
  static const Color sentBubble = Color(0xFF6C63FF);
  static const Color receivedBubble = Color(0xFF252540);
  static const Color aiBubble = Color(0xFF1A3A3A);

  // Status colors
  static const Color onlineColor = Color(0xFF4ECDC4);
  static const Color offlineColor = Color(0xFF888888);
  static const Color awayColor = Color(0xFFFFD93D);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: onSurfaceMuted),
        labelStyle: const TextStyle(color: onSurfaceMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onSurfaceMuted),
        labelLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: onSurfaceMuted),
        labelSmall: TextStyle(color: onSurfaceMuted),
      ),
      iconTheme: const IconThemeData(color: onSurface),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withOpacity(0.3),
        labelStyle: const TextStyle(color: onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
