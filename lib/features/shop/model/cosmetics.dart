import 'package:flutter/painting.dart';

/// A jar look: rim colour and the frosted interior's top/bottom tint.
class JarSkin {
  const JarSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.rim,
    required this.interiorTop,
    required this.interiorBottom,
    this.sparkles = false,
  });

  final String id;
  final String name;

  /// Coin price (0 = free / default).
  final int price;
  final Color rim;
  final Color interiorTop;
  final Color interiorBottom;

  /// Tiny stars painted on the glass.
  final bool sparkles;
}

/// A storybook backdrop palette.
class SceneTheme {
  const SceneTheme({
    required this.id,
    required this.name,
    required this.price,
    required this.skyTop,
    required this.skyMid,
    required this.skyHorizon,
    required this.hillFar,
    required this.hillNear,
    required this.grassDark,
    this.sun = const Color(0xFFFFF6D6),
    this.stars = false,
  });

  final String id;
  final String name;
  final int price;
  final Color skyTop;
  final Color skyMid;
  final Color skyHorizon;
  final Color hillFar;
  final Color hillNear;
  final Color grassDark;
  final Color sun;

  /// Twinkling stars in the sky (night themes).
  final bool stars;
}

abstract final class Cosmetics {
  static const jarSkins = [
    JarSkin(
      id: 'jar_classic',
      name: 'Classic Glass',
      price: 0,
      rim: Color(0xFFFFFFFF),
      interiorTop: Color(0xC7FFFBF6),
      interiorBottom: Color(0xE6FFEFE4),
    ),
    JarSkin(
      id: 'jar_strawberry',
      name: 'Strawberry Milk',
      price: 800,
      rim: Color(0xFFFFB3C9),
      interiorTop: Color(0xCCFFF0F5),
      interiorBottom: Color(0xE6FFDCE8),
    ),
    JarSkin(
      id: 'jar_mint',
      name: 'Mint Soda',
      price: 800,
      rim: Color(0xFFA8E6D6),
      interiorTop: Color(0xCCF0FFFA),
      interiorBottom: Color(0xE6D9F7EE),
    ),
    JarSkin(
      id: 'jar_starry',
      name: 'Starry Wish',
      price: 1500,
      rim: Color(0xFFC9B2FF),
      interiorTop: Color(0xCCF4EEFF),
      interiorBottom: Color(0xE6E4D9FF),
      sparkles: true,
    ),
  ];

  static const scenes = [
    SceneTheme(
      id: 'scene_meadow',
      name: 'Sunny Meadow',
      price: 0,
      skyTop: Color(0xFF8FC8FF),
      skyMid: Color(0xFFCBE5FF),
      skyHorizon: Color(0xFFFFE2EE),
      hillFar: Color(0xFFB9E3B0),
      hillNear: Color(0xFF8FD08A),
      grassDark: Color(0xFF5AAE55),
    ),
    SceneTheme(
      id: 'scene_sunset',
      name: 'Peach Sunset',
      price: 1000,
      skyTop: Color(0xFFFFA9B8),
      skyMid: Color(0xFFFFCBA4),
      skyHorizon: Color(0xFFFFEBC2),
      hillFar: Color(0xFFE7C6A0),
      hillNear: Color(0xFFC9D88A),
      grassDark: Color(0xFF9DBA62),
      sun: Color(0xFFFFE3B0),
    ),
    SceneTheme(
      id: 'scene_dreamy',
      name: 'Dreamy Night',
      price: 1500,
      skyTop: Color(0xFF7F86D9),
      skyMid: Color(0xFFB4A6EC),
      skyHorizon: Color(0xFFF2C9E6),
      hillFar: Color(0xFF9AB7D6),
      hillNear: Color(0xFF86B79A),
      grassDark: Color(0xFF5E9479),
      sun: Color(0xFFFFF4C8),
      stars: true,
    ),
  ];

  static JarSkin jar(String? id) =>
      jarSkins.firstWhere((j) => j.id == id, orElse: () => jarSkins.first);

  static SceneTheme scene(String? id) =>
      scenes.firstWhere((s) => s.id == id, orElse: () => scenes.first);

  /// Every cosmetic id (for validating saves).
  static Set<String> get allIds => {
    for (final j in jarSkins) j.id,
    for (final s in scenes) s.id,
  };

  /// Free items everyone owns.
  static Set<String> get defaults => {jarSkins.first.id, scenes.first.id};
}
