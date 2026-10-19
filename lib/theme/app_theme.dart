import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF14B85A);
  static const greenDeep = Color(0xFF0B6B38);
  static const yellow = Color(0xFFFFD21F);
  static const yellowSoft = Color(0xFFFFE56A);
  static const lime = Color(0xFFD4FF4A);
  static const cream = Color(0xFFEFF8EE);
  static const ink = Color(0xFF102017);
  static const seed = green;
  static const accent = green;
}

class AppRadii {
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.green,
      onPrimary: Colors.white,
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
      tertiary: AppColors.lime,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerHighest: const Color(0xFFD9EEDC),
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF3DDB7A),
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
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
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.yellow.withValues(alpha: 0.55),
        height: 44,
        labelPadding: const EdgeInsets.only(bottom: 1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.greenDeep : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.greenDeep : scheme.onSurfaceVariant,
            size: 18,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
