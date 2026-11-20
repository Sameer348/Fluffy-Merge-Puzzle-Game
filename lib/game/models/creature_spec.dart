import 'dart:ui';

/// Small decorative feature that makes each level recognisable by shape,
/// not only by color (accessibility).
enum CreatureAccessory {
  ears,
  blush,
  leaf,
  bow,
  sparkle,
  crown,
  flower,
  star,
  cloud,
  halo,
  moon,
  rainbow,
}

/// Plush animal ears drawn behind the head (in addition to the accessory).
enum EarStyle { none, cat, bunny }

/// Facial expression states. The renderer draws eyes/mouth per expression.
enum CreatureExpression { happy, surprised, squished, excited, worried, wink }

/// Static description of one creature level.
class CreatureSpec {
  const CreatureSpec({
    required this.level,
    required this.name,
    required this.personality,
    required this.body,
    required this.light,
    required this.shade,
    required this.radius,
    required this.accessory,
    this.bumps = 14,
    this.puff = 0.09,
    this.eyeScale = 1,
    this.freckles = false,
    this.lashes = false,
    this.catMouth = false,
    this.sparkleEyes = false,
    this.gradient,
    this.ears = EarStyle.none,
  });

  final int level;
  final String name;
  final String personality;

  /// Main body color, lighter top tone, and darker outline tone.
  final Color body;
  final Color light;
  final Color shade;

  /// Physics radius in world units (jar is 10 × 14 units).
  final double radius;
  final CreatureAccessory accessory;

  /// Number of fluffy scallops around the silhouette and how far they puff.
  final int bumps;
  final double puff;

  final double eyeScale;
  final bool freckles;
  final bool lashes;
  final bool catMouth;
  final bool sparkleEyes;

  /// Optional multi-stop body gradient (Rainbow Puff).
  final List<Color>? gradient;

  /// Cat or bunny ears (Tiny Puff's round ears are its accessory).
  final EarStyle ears;

  int get scoreValue => 10 * level;
}

/// The 12 original "Puff" creatures.
abstract final class CreatureCatalog {
  static const List<CreatureSpec> all = [
    CreatureSpec(
      level: 1,
      name: 'Tiny Puff',
      personality: 'Shy, but always first to say hi.',
      body: Color(0xFFFFCAD6),
      light: Color(0xFFFFE6EC),
      shade: Color(0xFFE79AAD),
      radius: 0.42,
      accessory: CreatureAccessory.ears,
      bumps: 12,
      eyeScale: 0.9,
    ),
    CreatureSpec(
      level: 2,
      name: 'Berry Puff',
      personality: 'Blushes at absolutely everything.',
      body: Color(0xFFFF8FA3),
      light: Color(0xFFFFC0CB),
      shade: Color(0xFFDB6F86),
      radius: 0.56,
      accessory: CreatureAccessory.blush,
      bumps: 13,
      ears: EarStyle.cat,
    ),
    CreatureSpec(
      level: 3,
      name: 'Lemon Puff',
      personality: 'Zesty, sunny and a little bit sour.',
      body: Color(0xFFFFDF85),
      light: Color(0xFFFFF1C2),
      shade: Color(0xFFE5B84F),
      radius: 0.71,
      accessory: CreatureAccessory.leaf,
      freckles: true,
    ),
    CreatureSpec(
      level: 4,
      name: 'Mint Puff',
      personality: 'Cool as a cucumber, sweet as candy.',
      body: Color(0xFF9FE0D2),
      light: Color(0xFFD3F4EC),
      shade: Color(0xFF6CC0AE),
      radius: 0.86,
      accessory: CreatureAccessory.bow,
      catMouth: true,
      ears: EarStyle.bunny,
    ),
    CreatureSpec(
      level: 5,
      name: 'Sky Puff',
      personality: 'Daydreams about flying kites.',
      body: Color(0xFF9CCBFF),
      light: Color(0xFFD4E8FF),
      shade: Color(0xFF6FA6E6),
      radius: 1.01,
      accessory: CreatureAccessory.sparkle,
      bumps: 15,
    ),
    CreatureSpec(
      level: 6,
      name: 'Lavender Puff',
      personality: 'Royalty of the toy box (self-declared).',
      body: Color(0xFFC7B3FF),
      light: Color(0xFFE6DDFF),
      shade: Color(0xFF9D86E6),
      radius: 1.16,
      accessory: CreatureAccessory.crown,
      lashes: true,
      ears: EarStyle.cat,
    ),
    CreatureSpec(
      level: 7,
      name: 'Peach Puff',
      personality: 'Gardens, giggles and naps in the sun.',
      body: Color(0xFFFFBE98),
      light: Color(0xFFFFE0CC),
      shade: Color(0xFFE5946A),
      radius: 1.32,
      accessory: CreatureAccessory.flower,
      lashes: true,
      bumps: 16,
      ears: EarStyle.bunny,
    ),
    CreatureSpec(
      level: 8,
      name: 'Bubble Puff',
      personality: 'Pops with excitement. Literally.',
      body: Color(0xFFFFA8D9),
      light: Color(0xFFFFD6EE),
      shade: Color(0xFFE07DB8),
      radius: 1.49,
      accessory: CreatureAccessory.star,
      catMouth: true,
      bumps: 16,
      ears: EarStyle.cat,
    ),
    CreatureSpec(
      level: 9,
      name: 'Cloud Puff',
      personality: 'So soft it forgets what it was doing.',
      body: Color(0xFFE9EFF8),
      light: Color(0xFFFFFFFF),
      shade: Color(0xFFB4C2D6),
      radius: 1.67,
      accessory: CreatureAccessory.cloud,
      bumps: 22,
      puff: 0.12,
    ),
    CreatureSpec(
      level: 10,
      name: 'Star Puff',
      personality: 'Glows brighter every time you smile.',
      body: Color(0xFFFFD36E),
      light: Color(0xFFFFEDB8),
      shade: Color(0xFFE0A93A),
      radius: 1.85,
      accessory: CreatureAccessory.halo,
      sparkleEyes: true,
      bumps: 18,
      ears: EarStyle.cat,
    ),
    CreatureSpec(
      level: 11,
      name: 'Moon Puff',
      personality: 'Hums lullabies to the smaller puffs.',
      body: Color(0xFFA9B4E8),
      light: Color(0xFFD6DCF7),
      shade: Color(0xFF7E8BCB),
      radius: 2.04,
      accessory: CreatureAccessory.moon,
      lashes: true,
      bumps: 18,
      ears: EarStyle.bunny,
    ),
    CreatureSpec(
      level: 12,
      name: 'Rainbow Puff',
      personality: 'The legendary fluffiest puff of all.',
      body: Color(0xFFFFE3F1),
      light: Color(0xFFFFFFFF),
      shade: Color(0xFFD9A3C6),
      radius: 2.24,
      accessory: CreatureAccessory.rainbow,
      sparkleEyes: true,
      bumps: 20,
      gradient: [
        Color(0xFFFFC2D1),
        Color(0xFFFFE7A3),
        Color(0xFFBDF0DA),
        Color(0xFFBFDDFF),
        Color(0xFFDCCBFF),
      ],
      ears: EarStyle.cat,
    ),
  ];

  static int get maxLevel => all.length;

  /// The home-screen mascot: a white, crowned kitty puff (not a level).
  static const CreatureSpec mascot = CreatureSpec(
    level: 0,
    name: 'Fluffy',
    personality: 'Keeper of the toy box.',
    body: Color(0xFFFFFBF7),
    light: Color(0xFFFFFFFF),
    shade: Color(0xFFE8D5D0),
    radius: 1,
    accessory: CreatureAccessory.crown,
    ears: EarStyle.cat,
    bumps: 20,
    puff: 0.11,
    eyeScale: 1.1,
    sparkleEyes: true,
  );

  /// 1-based lookup, clamped to the valid range.
  static CreatureSpec byLevel(int level) =>
      all[(level - 1).clamp(0, all.length - 1)];
}
