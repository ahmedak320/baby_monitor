import 'package:flutter/material.dart';

/// YouTube-mirror dark theme for kid mode.
/// Matches YouTube's actual dark mode colors so kids feel at home.
class KidTheme {
  KidTheme._();

  // YouTube dark mode colors
  static const background = Color(0xFF0F0F0F);
  static const surface = Color(0xFF212121);
  static const surfaceVariant = Color(0xFF272727);
  static const youtubeRed = Color(0xFFFF0000);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const bottomNav = Color(0xFF212121);

  // TV focus constants
  static const tvFocusBorderColor = Color(0xFFFFFFFF);
  static const tvFocusBorderWidth = 3.0;
  static const tvFocusScaleFactor = 1.05;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: youtubeRed,
          secondary: youtubeRed,
          surface: surface,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bottomNav,
          selectedItemColor: textPrimary,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
          bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        ),
        cardTheme: CardThemeData(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: youtubeRed,
            foregroundColor: textPrimary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF383838),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceVariant,
          selectedColor: textPrimary,
          labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}
