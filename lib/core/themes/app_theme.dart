import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Named Color Constants (used by painters & widgets) ──
  static const Color neonCyan   = Color(0xFF00CEC9);
  static const Color neonPurple = Color(0xFF6C5CE7);
  static const Color kNeonCyan   = neonCyan;     // alias for backward compat
  static const Color kNeonPurple = neonPurple;   // alias for backward compat
  static const Color kSurface   = Color(0xFF1E1E2C);
  static const Color kDeepBg    = Color(0xFF141422);
  static const Color kErrorRed  = Color(0xFFFF6B6B);
  static const Color kTextDim   = Color(0x99E0E0E0);
  static const Color kGlassWhite = Color(0x14FFFFFF);

  // ── Private palette ─────────────────────────────────────
  static const Color _primaryColor   = neonPurple;
  static const Color _secondaryColor = neonCyan;
  static const Color _surfaceColor   = kSurface;
  static const Color _backgroundColor = kDeepBg;
  static const Color _errorColor     = kErrorRed;
  static const Color _onPrimary      = Colors.white;
  static const Color _onSurface      = Color(0xFFE0E0E0);

  // ── Dark Theme ───────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: _surfaceColor,
        error: _errorColor,
        onPrimary: _onPrimary,
        onSurface: _onSurface,
      ),
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: _onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: _onSurface.withAlpha(128)),
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
