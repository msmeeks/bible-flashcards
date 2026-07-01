import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF1B5E6B);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ).copyWith(
      // Primary — Deep Teal
      primary: const Color(0xFF1B5E6B),
      primaryContainer: const Color(0xFFC8E9EE),
      onPrimary: const Color(0xFFFFFFFF),
      onPrimaryContainer: const Color(0xFF001F24),

      // Secondary — Warm Sand
      secondary: const Color(0xFF7D5A3C),
      secondaryContainer: const Color(0xFFF5DFC8),
      onSecondary: const Color(0xFFFFFFFF),
      onSecondaryContainer: const Color(0xFF2B1700),

      // Tertiary — Muted Gold
      tertiary: const Color(0xFF8A6914),
      tertiaryContainer: const Color(0xFFFDEFC3),
      onTertiary: const Color(0xFFFFFFFF),
      onTertiaryContainer: const Color(0xFF281900),

      // Neutral / Surface
      surface: const Color(0xFFF8F5F0),
      surfaceVariant: const Color(0xFFEDE7DE),
      outline: const Color(0xFF8A7E72),
      onSurface: const Color(0xFF1C1917),
      onSurfaceVariant: const Color(0xFF4D453E),
      inverseSurface: const Color(0xFF312E2B),
      onInverseSurface: const Color(0xFFF5EFE9),

      // Error
      error: const Color(0xFFBA1A1A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      textTheme: _buildTextTheme(base),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.surfaceVariant,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: base.primary, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.surface,
        indicatorColor: base.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF4FBDCF),
      surface: const Color(0xFF1C1917),
      onSurface: const Color(0xFFEDE7DE),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      textTheme: _buildTextTheme(base),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.surfaceContainerHighest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: base.primary, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: base.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  /// Lora for headline/body (Scripture text), system sans for label/title (UI chrome).
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    final loraBase = GoogleFonts.loraTextTheme();
    final onSurface = scheme.onSurface;
    return TextTheme(
      // Scripture text — Lora serif
      displayLarge: loraBase.displayLarge?.copyWith(color: onSurface),
      displayMedium: loraBase.displayMedium?.copyWith(color: onSurface),
      displaySmall: loraBase.displaySmall?.copyWith(color: onSurface),
      headlineLarge: loraBase.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineMedium: loraBase.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineSmall: loraBase.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyLarge: loraBase.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: loraBase.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),

      // UI chrome — system sans
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
    );
  }
}
