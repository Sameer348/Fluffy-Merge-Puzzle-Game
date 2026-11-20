import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../constants/app_sizes.dart';
import '../constants/game_constants.dart';

/// Device size class used to tweak layout (not to hard-code it).
enum DeviceClass { compactPhone, phone, tablet }

/// Lightweight responsive helper built from a [Size] (usually from
/// [LayoutBuilder] constraints or [MediaQuery]).
@immutable
class Responsive {
  const Responsive._(this.size, this.scale, this.deviceClass);

  factory Responsive.of(Size size) {
    final shortest = size.shortestSide;
    final deviceClass = shortest >= 600
        ? DeviceClass.tablet
        : (size.height < 700 || size.width < 360)
        ? DeviceClass.compactPhone
        : DeviceClass.phone;

    // Scale relative to the design reference, limited by both axes so
    // short-and-wide or tall-and-narrow screens don't overflow.
    final widthScale = size.width / AppSizes.designWidth;
    final heightScale = size.height / AppSizes.designHeight;
    final scale = math.min(widthScale, heightScale).clamp(0.78, 1.35);
    return Responsive._(size, scale.toDouble(), deviceClass);
  }

  factory Responsive.fromContext(BuildContext context) =>
      Responsive.of(MediaQuery.sizeOf(context));

  final Size size;
  final double scale;
  final DeviceClass deviceClass;

  bool get isTablet => deviceClass == DeviceClass.tablet;
  bool get isCompact => deviceClass == DeviceClass.compactPhone;

  /// Scale a design-px value.
  double s(double v) => v * scale;

  /// Grid column count for collection-style grids.
  int get gridColumns => isTablet ? 6 : 4;
}

/// Computed rectangles for the gameplay screen. Pure math so it is easy to
/// unit-test and reuse from both Flutter widgets and the Flame game.
@immutable
class GameLayout {
  const GameLayout({
    required this.hud,
    required this.jar,
    required this.powerBar,
  });

  final Rect hud;
  final Rect jar;
  final Rect powerBar;

  /// Splits [size] (the safe area) into HUD / jar / power-up bar while
  /// preserving the jar's world aspect ratio.
  factory GameLayout.compute(Size size) {
    final r = Responsive.of(size);
    final pad = r.s(16);
    final hudH = r.s(r.isCompact ? 56 : 68);
    final barH = r.s(r.isCompact ? 84 : 100);

    final availW = size.width - pad * 2;
    final availH = size.height - hudH - barH - pad * 2;

    // Fit jar to available space with fixed aspect (letterbox if needed).
    var jarW = availW;
    var jarH = jarW / GameConstants.jarAspect;
    if (jarH > availH) {
      jarH = availH;
      jarW = jarH * GameConstants.jarAspect;
    }

    final hud = Rect.fromLTWH(0, 0, size.width, hudH);
    final jarTop = hudH + pad + (availH - jarH) / 2;
    final jar = Rect.fromLTWH((size.width - jarW) / 2, jarTop, jarW, jarH);
    final powerBar = Rect.fromLTWH(0, size.height - barH, size.width, barH);
    return GameLayout(hud: hud, jar: jar, powerBar: powerBar);
  }
}
