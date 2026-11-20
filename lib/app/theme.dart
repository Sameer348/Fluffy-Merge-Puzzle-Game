import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';

/// Rounded, friendly type: Fredoka for display/titles, Nunito for body.
///
/// Both ship inside the app (assets/fonts, SIL Open Font License), so text
/// renders correctly on first launch, offline, with no font downloads.
abstract final class AppText {
  static const String displayFamily = 'Fredoka';
  static const String bodyFamily = 'Nunito';

  static TextStyle display(double size, {Color color = AppColors.textDark}) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.1,
      );

  static TextStyle body(
    double size, {
    Color color = AppColors.textDark,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.3,
  );
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.coral,
          onPrimary: AppColors.white,
          secondary: AppColors.mint,
          onSecondary: AppColors.textDark,
          tertiary: AppColors.lavender,
          surface: AppColors.cream,
          onSurface: AppColors.textDark,
          error: AppColors.danger,
        );

    final textTheme = TextTheme(
      displayLarge: AppText.display(34), // game title
      displayMedium: AppText.display(30),
      displaySmall: AppText.display(26), // large score
      headlineMedium: AppText.display(22),
      titleLarge: AppText.display(20),
      titleMedium: AppText.body(17, weight: FontWeight.w800),
      bodyLarge: AppText.body(17, weight: FontWeight.w600),
      bodyMedium: AppText.body(15, weight: FontWeight.w600),
      labelLarge: AppText.body(15, weight: FontWeight.w800),
      labelMedium: AppText.body(13, color: AppColors.softBrown),
      labelSmall: AppText.body(11, color: AppColors.softBrown),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textDark,
        titleTextStyle: AppText.display(24),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppSizes.cardRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        shape: const RoundedRectangleBorder(borderRadius: AppSizes.cardRadius),
        titleTextStyle: AppText.display(24),
        contentTextStyle: AppText.body(16, weight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.jarBorder,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.coral,
        inactiveTrackColor: AppColors.jarBorder,
        thumbColor: AppColors.coral,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    );
  }
}
