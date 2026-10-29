import 'package:flutter/material.dart';

/// Road Navy tokens from the desk (`web/src/styles/tokens.css`) plus the
/// Flutter mockup extras (Geist, brand lime for live, night/weather data colors).
class AppColors {
  static const bg = Color(0xFFF6F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDBE2E9);
  static const text = Color(0xFF0F1B2D);
  static const textMuted = Color(0xFF525F6F);
  static const primary = Color(0xFF1156C1);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFFF9AD26);
  static const success = Color(0xFF027E47);
  static const warning = Color(0xFFB64E10);
  static const danger = Color(0xFFC92324);

  static const bgDark = Color(0xFF0A121F);
  static const surfaceDark = Color(0xFF131D2D);
  static const borderDark = Color(0xFF283345);
  static const textDark = Color(0xFFEDF2F8);
  static const textMutedDark = Color(0xFF9EACBE);
  static const primaryDark = Color(0xFF65A7FA);
  static const onPrimaryDark = Color(0xFF071123);
  static const accentDark = Color(0xFFFABB41);
  static const successDark = Color(0xFF56D089);

  /// Desk aliases so practice/instruction widgets keep the old names.
  static const cream = bg;
  static const ink = text;
  static const lime = primary;
  static const green = success;
  static const greenDeep = success;
  static const yellow = accent;
  static const yellowSoft = Color(0xFFFBD78A);
  static const seed = primary;
}

/// Mockup token class (`LL.s4`, `LL.brandLime`). Same palette as [AppColors].
class LL {
  LL._();

  static const bg = AppColors.bg;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const text = AppColors.text;
  static const textMuted = AppColors.textMuted;
  static const primary = AppColors.primary;
  static const onPrimary = AppColors.onPrimary;
  static const accent = AppColors.accent;
  static const success = AppColors.success;
  static const warning = AppColors.warning;
  static const danger = AppColors.danger;

  static const surface2 = Color(0xFFF5F6F7);
  static const borderStrong = Color(0xFFB6BEC7);
  static const primarySoft = Color(0x241156C1);
  static const accentSoft = Color(0x38F9AD26);
  static const successSoft = Color(0x24027E47);
  static const warningSoft = Color(0x24B64E10);
  static const dangerSoft = Color(0x24C92324);

  static const brandLime = Color(0xFFD4FF4A);
  static const brandLimeInk = Color(0xFF0F1B2D);
  static const night = Color(0xFF3B3F8F);
  static const weather = Color(0xFF17788A);
  static const mapBg = Color(0xFFEEF2F6);

  static const cream = bg;
  static const ink = text;
  static const lime = primary;
  static const green = success;
  static const yellow = accent;

  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0, s7 = 48.0;
  static const rSm = 8.0, rMd = 12.0, rLg = 18.0, rPill = 999.0;
  static const fsXs = 12.0, fsSm = 14.0, fsMd = 16.0, fsLg = 18.0, fsXl = 22.0, fs2xl = 28.0, fs3xl = 40.0;
  static const sans = 'Geist';
  static const mono = 'GeistMono';

  static const shadowSm = [BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1))];
  static const shadowMd = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x24132033), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 8)),
  ];
  static const glowPrimary = [
    BoxShadow(color: Color(0x591156C1), spreadRadius: 1),
    BoxShadow(color: Color(0x731156C1), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 8)),
  ];

  static const durFast = Duration(milliseconds: 120);
  static const durMed = Duration(milliseconds: 220);
  static const easeOut = Cubic(.2, .8, .2, 1);
  static const tnum = [FontFeature.tabularFigures(), FontFeature.slashedZero()];
}

TextStyle llText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = LL.text,
  bool mono = false,
  bool numeric = false,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: mono ? LL.mono : LL.sans,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing ?? (size >= LL.fsXl ? -0.02 * size : null),
    fontFeatures: numeric || mono ? LL.tnum : null,
  );
}

TextStyle llLabel({Color color = LL.textMuted}) =>
    llText(LL.fsXs, weight: FontWeight.w600, color: color, letterSpacing: 0.06 * LL.fsXs);

class AppRadii {
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.text,
      tertiary: AppColors.success,
      surface: AppColors.bg,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerHighest: const Color(0xFFE4EAF1),
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.onPrimaryDark,
      secondary: AppColors.accentDark,
      onSecondary: AppColors.text,
      tertiary: AppColors.successDark,
      surface: AppColors.bgDark,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMutedDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark,
      error: const Color(0xFFFA6863),
      surfaceContainerLowest: AppColors.surfaceDark,
      surfaceContainerHighest: AppColors.borderDark,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final text = (brightness == Brightness.dark
            ? Typography.whiteMountainView
            : Typography.blackMountainView)
        .apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamily: LL.sans,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.apply(fontFamily: LL.sans).copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontFamily: LL.sans,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontFamily: LL.sans,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LL.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: LL.primarySoft,
        indicatorShape: const StadiumBorder(),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return llText(
            LL.fsXs,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? LL.primary : LL.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? LL.primary : LL.textMuted,
            size: 22,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
