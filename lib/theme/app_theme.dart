import 'package:flutter/material.dart';

/// Soft Keep-like pastel palette for memo cards.
class MemoColors {
  static const List<Color> noteColors = [
    Color(0xFFFFF9C4), // yellow
    Color(0xFFFFCCBC), // coral
    Color(0xFFC8E6C9), // green
    Color(0xFFBBDEFB), // blue
    Color(0xFFE1BEE7), // purple
    Color(0xFFFFE0B2), // orange
    Color(0xFFB2EBF2), // cyan
    Color(0xFFF5F5F5), // gray
  ];

  static Color forIndex(int index) {
    if (noteColors.isEmpty) {
      return Colors.white;
    }
    return noteColors[index % noteColors.length];
  }
}

class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFFF4B400);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFBF0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFFDF8),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF202124),
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
