import 'package:flutter/material.dart';

/// "Cozy Kawaii Toy Box" palette. Every color in the app should come from
/// here so the look stays consistent and easy to retune.
abstract final class AppColors {
  // Backgrounds
  static const cream = Color(0xFFFFF8F0);
  static const peachCream = Color(0xFFFFF1E6);

  // Accents
  static const coral = Color(0xFFFF8FA3);
  static const mint = Color(0xFF8FD3C7);
  static const sunshine = Color(0xFFFFD166);
  static const lavender = Color(0xFFB8A1FF);
  static const sky = Color(0xFF8EC5FF);

  // Text
  static const textDark = Color(0xFF4A3F45);
  static const softBrown = Color(0xFF8C7470);

  // Status
  static const success = Color(0xFF78C091);
  static const danger = Color(0xFFF26B6B);

  static const white = Color(0xFFFFFFFF);

  // Derived tones (used sparingly for depth on plush/toy surfaces).
  static const coralDeep = Color(0xFFE97389);
  static const mintDeep = Color(0xFF6DBFB1);
  static const sunshineDeep = Color(0xFFF2B93F);
  static const lavenderDeep = Color(0xFF9C82F0);
  static const skyDeep = Color(0xFF6FAEF0);

  /// Jar interior and its rim.
  static const jarInterior = Color(0xFFFFFCF8);
  static const jarBorder = Color(0xFFF3DED0);

  /// Warm, low-contrast shadow tint (never pure black).
  static const shadow = Color(0x334A3F45);
  static const shadowSoft = Color(0x1A4A3F45);

  // --- Storybook scene (sky, meadow) ---
  static const skyTop = Color(0xFF8FC8FF);
  static const skyMid = Color(0xFFCBE5FF);
  static const skyHorizon = Color(0xFFFFE2EE);
  static const cloud = Color(0xFFFFFFFF);
  static const cloudShade = Color(0xFFE9E3FF);
  static const hillFar = Color(0xFFB9E3B0);
  static const hillNear = Color(0xFF8FD08A);
  static const grass = Color(0xFF7CC66E);
  static const grassDark = Color(0xFF5AAE55);
  static const dirt = Color(0xFFE2B47C);
  static const dirtDark = Color(0xFFC98E52);

  // --- Candy buttons (top / bottom of the glossy gradient, lip) ---
  static const candyPinkTop = Color(0xFFFF8CC0);
  static const candyPink = Color(0xFFF0478E);
  static const candyPinkLip = Color(0xFFC72E6E);
  static const candyGreenTop = Color(0xFF8BE07A);
  static const candyGreen = Color(0xFF3DB54A);
  static const candyGreenLip = Color(0xFF2B8A36);
  static const candyBlueTop = Color(0xFF7CCBFF);
  static const candyBlue = Color(0xFF2F8FE8);
  static const candyBlueLip = Color(0xFF1F6BB5);
  static const candyYellowTop = Color(0xFFFFEA8A);
  static const candyYellow = Color(0xFFFFC22E);
  static const candyYellowLip = Color(0xFFD99A12);
  static const candyPurpleTop = Color(0xFFB98CFF);
  static const candyPurple = Color(0xFF7B4FE0);
  static const candyPurpleLip = Color(0xFF5733AE);

  // --- Logo, wood signs, cream panels ---
  static const logoPurple = Color(0xFF6E3AA7);
  static const logoGoldTop = Color(0xFFFFE680);
  static const logoGold = Color(0xFFFFB52E);
  static const woodTop = Color(0xFFEFA963);
  static const wood = Color(0xFFCF7A38);
  static const woodDark = Color(0xFF9A5424);
  static const panel = Color(0xFFFFF6E6);
  static const panelBorder = Color(0xFFF0D3A8);
  static const panelInset = Color(0xFFFBEAD0);

  /// Plain cream gradient (fallback behind the storybook scene).
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cream, peachCream],
  );
}
