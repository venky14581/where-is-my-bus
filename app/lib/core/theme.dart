import 'package:flutter/material.dart';

// Amrita maroon. Used as the seed so both themes stay on-brand; the
// fidelity variant keeps the primary close to the real maroon instead of a
// washed-out tone.
const _seed = Color(0xFF8C1D40);

/// Corner radii, shared so cards, sheets and buttons look like one family.
abstract final class Radii {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const sheet = 28.0;
}

/// Colours for states the colour scheme has no slot for: a bus that is live
/// or at the stop. Picked to stay readable in light and dark.
extension StatusColors on ColorScheme {
  Color get success => brightness == Brightness.light ? const Color(0xFF1B7A3D) : const Color(0xFF7DD99A);
  Color get successContainer => brightness == Brightness.light ? const Color(0xFFD5F2DD) : const Color(0xFF14462A);
  Color get onSuccessContainer => brightness == Brightness.light ? const Color(0xFF0B3A1C) : const Color(0xFFD5F2DD);
  Color get warning => brightness == Brightness.light ? const Color(0xFF8A5A00) : const Color(0xFFF2C46B);
  Color get warningContainer => brightness == Brightness.light ? const Color(0xFFFFE7B8) : const Color(0xFF4A3300);
  Color get onWarningContainer => brightness == Brightness.light ? const Color(0xFF3B2600) : const Color(0xFFFFE7B8);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  RoundedRectangleBorder rounded(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      shape: rounded(Radii.large),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.medium)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.medium),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: rounded(Radii.medium),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: rounded(Radii.medium),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: rounded(Radii.small),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(shape: rounded(Radii.small), side: BorderSide(color: scheme.outlineVariant)),
    dialogTheme: DialogThemeData(shape: rounded(Radii.sheet)),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded(Radii.small),
    ),
    listTileTheme: ListTileThemeData(shape: rounded(Radii.medium)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(shape: rounded(Radii.medium)),
    ),
  );
}
