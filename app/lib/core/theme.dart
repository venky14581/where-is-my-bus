import 'package:flutter/material.dart';

// Amrita maroon. Used as the seed so both themes stay on-brand.
const _seed = Color(0xFF8C1D40);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: rounded,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: rounded),
    ),
    cardTheme: CardThemeData(shape: rounded, margin: EdgeInsets.zero),
  );
}
