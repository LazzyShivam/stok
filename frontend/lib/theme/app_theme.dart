import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Custom color extension for app-specific colors
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.divider,
    required this.sentBubble,
    required this.receivedBubble,
    required this.aiBubble,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color divider;
  final Color sentBubble;
  final Color receivedBubble;
  final Color aiBubble;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? divider,
    Color? sentBubble,
    Color? receivedBubble,
    Color? aiBubble,
  }) =>
      AppColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        onSurface: onSurface ?? this.onSurface,
        onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
        divider: divider ?? this.divider,
        sentBubble: sentBubble ?? this.sentBubble,
        receivedBubble: receivedBubble ?? this.receivedBubble,
        aiBubble: aiBubble ?? this.aiBubble,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      sentBubble: Color.lerp(sentBubble, other.sentBubble, t)!,
      receivedBubble: Color.lerp(receivedBubble, other.receivedBubble, t)!,
      aiBubble: Color.lerp(aiBubble, other.aiBubble, t)!,
    );
  }

  static const dark = AppColors(
    background: Color(0xFF0E0E1A),
    surface: Color(0xFF1A1A2E),
    surfaceVariant: Color(0xFF252540),
    onSurface: Color(0xFFE0E0F0),
    onSurfaceMuted: Color(0xFF8888AA),
    divider: Color(0xFF2A2A45),
    sentBubble: Color(0xFF6C63FF),
    receivedBubble: Color(0xFF252540),
    aiBubble: Color(0xFF1A3A3A),
  );

  static const light = AppColors(
    background: Color(0xFFF5F5FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEEEEF8),
    onSurface: Color(0xFF1A1A2E),
    onSurfaceMuted: Color(0xFF6B6B8A),
    divider: Color(0xFFE0E0EE),
    sentBubble: Color(0xFF6C63FF),
    receivedBubble: Color(0xFFEEEEF8),
    aiBubble: Color(0xFFE0F5F0),
  );
}

class AppTheme {
  // Brand colors (same in both themes)
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52E0);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ECDC4);
  static const Color warning = Color(0xFFFFD93D);
  static const Color onlineColor = Color(0xFF4ECDC4);
  static const Color offlineColor = Color(0xFF888888);
  static const Color awayColor = Color(0xFFFFD93D);

  // Dark theme static colors (for backward compat with widgets that use AppTheme.xxx directly)
  static const Color background = Color(0xFF0E0E1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF252540);
  static const Color onSurface = Color(0xFFE0E0F0);
  static const Color onSurfaceMuted = Color(0xFF8888AA);
  static const Color divider = Color(0xFF2A2A45);
  static const Color sentBubble = Color(0xFF6C63FF);
  static const Color receivedBubble = Color(0xFF252540);
  static const Color aiBubble = Color(0xFF1A3A3A);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark, AppColors.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light, AppColors.light);

  static ThemeData _buildTheme(Brightness brightness, AppColors colors) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: error,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.onSurface,
        surfaceContainerHighest: colors.surfaceVariant,
        outline: colors.divider,
      ),
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colors.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: primary,
        unselectedItemColor: colors.onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
        labelStyle: TextStyle(color: colors.onSurfaceMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      textTheme: TextTheme(
        displayLarge:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        displayMedium:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        displaySmall:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        headlineLarge:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
        headlineSmall:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500),
        titleSmall:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: colors.onSurface),
        bodyMedium: TextStyle(color: colors.onSurface),
        bodySmall: TextStyle(color: colors.onSurfaceMuted),
        labelLarge:
            TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: colors.onSurfaceMuted),
        labelSmall: TextStyle(color: colors.onSurfaceMuted),
      ),
      iconTheme: IconThemeData(color: colors.onSurface),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        selectedColor: primary.withOpacity(0.3),
        labelStyle: TextStyle(color: colors.onSurface),
        side: BorderSide.none,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Extension for easy context access
extension AppThemeContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
