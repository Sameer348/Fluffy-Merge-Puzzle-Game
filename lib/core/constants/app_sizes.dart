import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing, radii, shadows and animation timings.
abstract final class AppSizes {
  // Spacing scale (multiplied by Responsive.scale at use sites when needed).
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radii
  static const double radiusCard = 24; // major cards 20–28
  static const double radiusButton = 20; // buttons 18–24
  static const double radiusChip = 14;
  static const double radiusJar = 28;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(radiusButton),
  );

  /// Minimum accessible tap target.
  static const double minTap = 48;

  /// Design reference width (iPhone 14/15). Used for scaling.
  static const double designWidth = 390;
  static const double designHeight = 844;

  /// Max content width on tablets so menus don't stretch edge to edge.
  static const double maxContentWidth = 560;
}

abstract final class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.shadowSoft,
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowSoft,
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
    BoxShadow(color: AppColors.shadowSoft, blurRadius: 4, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> button(Color base) => [
    BoxShadow(
      color: base.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 320);
  static const stagger = Duration(milliseconds: 70);
}

abstract final class AppCurves {
  static const bouncy = Curves.easeOutBack;
  static const soft = Curves.easeOutCubic;
}
