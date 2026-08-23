import 'package:flutter/material.dart';

/// Visual theming for LEV.
///
/// The palette is deliberately muted and low-contrast-in-hue: the product's
/// purpose is to calm and stabilise, so nothing in the interface should
/// compete for attention or read as urgent.
abstract final class AppTheme {
  /// Seed colour for both schemes — a soft, desaturated teal.
  static const Color _seed = Color(0xFF4F7C82);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
