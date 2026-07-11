import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Eco Breeze Theme
  static const Color background =
      Color(0xFFF8F9FA); // Off-white clean background
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards/surfaces
  static const Color surfaceContainer =
      Color(0xFFE9ECEF); // Soft grey container
  static const Color surfaceContainerHigh = Color(0xFFDEE2E6);
  static const Color surfaceContainerHighest = Color(0xFFCED4DA);

  static const Color onSurface = Color(0xFF1A1A1A); // Dark charcoal text
  static const Color onSurfaceVariant = Color(0xFF6C757D); // Subtle grey text
  static const Color surfaceVariant = Color(0xFFE9ECEF);

  // Greens
  static const Color primary = Color(0xFF00C675); // Emerald Green
  static const Color onPrimary = Color(0xFFFFFFFF); // White text on green
  static const Color primaryContainer = Color(0xFF00A360); // Darker green
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed =
      Color(0xFFE6F9F0); // Very light mint/green tint
  static const Color primaryFixedDim = Color(0xFFB3EDD5);

  // Accents
  static const Color secondary = Color(0xFF00E5FF); // Electric Cyan accent
  static const Color onSecondary = Color(0xFF0A192F);
  static const Color secondaryContainer = Color(0xFFE0F4FF);
  static const Color onSecondaryContainer = Color(0xFF005BFF);

  static const Color tertiary = Color(0xFFFFB68B);
  static const Color onTertiary = Color(0xFF522300);
  static const Color tertiaryContainer = Color(0xFFFF7A00);
  static const Color onTertiaryContainer = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFDC3545);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF8D7DA);
  static const Color onErrorContainer = Color(0xFF721C24);

  static const Color outline = Color(0xFFDEE2E6);
  static const Color outlineVariant = Color(0xFFE9ECEF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.audiowide(
          color: primaryContainer,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02,
            height: 1.1,
            color: onSurface),
        headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: onSurface),
        headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: onSurface),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: onSurface),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: onSurface),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            height: 1.0,
            color: onSurface),
        labelSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: onSurfaceVariant),
      ),
    );
  }
}
