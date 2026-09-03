import 'package:flutter/material.dart';

/// Design tokens lifted 1:1 from design/redesign/preview.html.
class T {
  static const blue = Color(0xFF0A84FF);
  static const blueSoft = Color(0xFFE5F1FF);
  static const green = Color(0xFF30D158);
  static const greenDark = Color(0xFF248A3D);
  static const orange = Color(0xFFFF9F0A);
  static const red = Color(0xFFFF453A);
  static const indigo = Color(0xFF5E5CE6);

  static const bg = Color(0xFFF2F2F7);
  static const card = Colors.white;
  static const label = Color(0xFF1C1C1E);
  static const secondary = Color(0xFF8E8E93);
  static const tertiary = Color(0xFFC7C7CC);
  static const separator = Color(0xFFE5E5EA);

  static const sheetBg = Color(0xFFF7F7FA);
  static const fieldBg = Color(0xFFE9E9EB);

  static const font = 'Inter';

  static ThemeData theme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: cs.copyWith(
        primary: blue,
        secondary: green,
        surface: brightness == .dark ? const Color(0xFF1C1C1E) : card,
        error: red,
      ),
      scaffoldBackgroundColor:
          brightness == .dark ? const Color(0xFF000000) : bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: blue,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: brightness == .dark ? Colors.white : label,
        ),
      ),
      dividerTheme: const DividerThemeData(color: separator, thickness: .5),
    );
  }
}

/// Static color helper that flips for dark mode (kept simple: light-first).
Color ink(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white : T.label;
Color sub(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.tertiary : T.secondary;
Color surface(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : T.card;
Color sep(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : T.separator;
