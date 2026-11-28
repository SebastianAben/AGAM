import 'package:flutter/material.dart';

/// AGAM tokens, taken from the onboarding: the logo's navy and cyan, the
/// teal and forest grounds, white sheets over coloured grounds, and a cool
/// blue-grey surface instead of the earlier lavender tints.
abstract final class AgamColors {
  static const brand = Color(0xFF124DA5);
  static const brandDeep = Color(0xFF0D3F8F);
  static const teal = Color(0xFF0A6A7E);
  static const forest = Color(0xFF0D564D);
  static const cyan = Color(0xFF3FD0EE);
  static const mint = Color(0xFF64F3BF);

  static const ink = Color(0xFF17213A);
  static const muted = Color(0xFF5B6070);
  static const subtle = Color(0xFF878D9C);

  static const canvas = Color(0xFFF5F7FB);
  static const fill = Color(0xFFEEF2F8);
  static const tint = Color(0xFFE2F0FB);
  static const line = Color(0xFFE3E8F0);

  static const success = Color(0xFF0E7C66);
  static const successTint = Color(0xFFE1F3EE);
  static const warning = Color(0xFFB4541A);
  static const danger = Color(0xFFB3261E);
  static const dangerTint = Color(0xFFFBE9E7);
}

abstract final class AgamRadius {
  static const sheet = 28.0;
  static const card = 24.0;
  static const tile = 18.0;
  static const control = 16.0;
}

abstract final class AgamShadows {
  /// Resting cards on the canvas.
  static const card = [
    BoxShadow(color: Color(0x0F0B1F44), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Controls that float over the map.
  static const floating = [
    BoxShadow(color: Color(0x290B1F44), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// The coloured glow under the primary action, as on the onboarding CTA.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: .3),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

abstract final class AgamText {
  static const display = TextStyle(
    color: AgamColors.ink,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
  static const title = TextStyle(
    color: AgamColors.ink,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const headline = TextStyle(
    color: AgamColors.ink,
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const label = TextStyle(
    color: AgamColors.ink,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    color: AgamColors.muted,
    fontSize: 15,
    height: 1.5,
  );
  static const bodySmall = TextStyle(
    color: AgamColors.muted,
    fontSize: 13,
    height: 1.45,
  );
  static const caption = TextStyle(
    color: AgamColors.muted,
    fontSize: 12,
    height: 1.35,
  );
  static const overline = TextStyle(
    color: AgamColors.brand,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}

/// Plus Jakarta Sans joins "fi" into one glyph without the dot on the i, so
/// words such as "Profil" and "Notifikasi" read like typos. Every text style
/// in the theme turns standard ligatures off.
const _noLigatures = [FontFeature.disable('liga')];

TextTheme _withoutLigatures(TextTheme theme) {
  TextStyle? plain(TextStyle? style) =>
      style?.copyWith(fontFeatures: _noLigatures);
  return theme.copyWith(
    displayLarge: plain(theme.displayLarge),
    displayMedium: plain(theme.displayMedium),
    displaySmall: plain(theme.displaySmall),
    headlineLarge: plain(theme.headlineLarge),
    headlineMedium: plain(theme.headlineMedium),
    headlineSmall: plain(theme.headlineSmall),
    titleLarge: plain(theme.titleLarge),
    titleMedium: plain(theme.titleMedium),
    titleSmall: plain(theme.titleSmall),
    bodyLarge: plain(theme.bodyLarge),
    bodyMedium: plain(theme.bodyMedium),
    bodySmall: plain(theme.bodySmall),
    labelLarge: plain(theme.labelLarge),
    labelMedium: plain(theme.labelMedium),
    labelSmall: plain(theme.labelSmall),
  );
}

ThemeData agamTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AgamColors.brand,
    primary: AgamColors.brand,
    surface: Colors.white,
  );
  final theme = _baseTheme(scheme);
  return theme.copyWith(
    textTheme: _withoutLigatures(theme.textTheme),
    primaryTextTheme: _withoutLigatures(theme.primaryTextTheme),
  );
}

ThemeData _baseTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AgamColors.canvas,
    fontFamily: 'PlusJakartaSans',
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AgamColors.ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'PlusJakartaSans',
        fontFeatures: _noLigatures,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AgamRadius.card),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgamRadius.sheet),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AgamColors.ink,
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
