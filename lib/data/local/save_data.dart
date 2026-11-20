import 'package:flutter/foundation.dart';

import '../../game/models/power_up.dart';

/// Player settings (UI for these arrives in Phase 15).
@immutable
class GameSettings {
  const GameSettings({
    this.music = true,
    this.sfx = true,
    this.haptics = true,
    this.reducedMotion = false,
    this.musicVolume = 0.6,
    this.sfxVolume = 0.8,
  });

  final bool music;
  final bool sfx;
  final bool haptics;

  /// In-app reduce-motion toggle (OR-ed with the OS setting).
  final bool reducedMotion;
  final double musicVolume;
  final double sfxVolume;

  GameSettings copyWith({
    bool? music,
    bool? sfx,
    bool? haptics,
    bool? reducedMotion,
    double? musicVolume,
    double? sfxVolume,
  }) => GameSettings(
    music: music ?? this.music,
    sfx: sfx ?? this.sfx,
    haptics: haptics ?? this.haptics,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    musicVolume: musicVolume ?? this.musicVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
  );

  Map<String, Object?> toJson() => {
    'music': music,
    'sfx': sfx,
    'haptics': haptics,
    'reducedMotion': reducedMotion,
    'musicVolume': musicVolume,
    'sfxVolume': sfxVolume,
  };

  factory GameSettings.fromJson(Object? json) {
    final m = _map(json);
    const d = GameSettings();
    return GameSettings(
      music: _bool(m['music'], d.music),
      sfx: _bool(m['sfx'], d.sfx),
      haptics: _bool(m['haptics'], d.haptics),
      reducedMotion: _bool(m['reducedMotion'], d.reducedMotion),
      musicVolume: _unit(m['musicVolume'], d.musicVolume),
      sfxVolume: _unit(m['sfxVolume'], d.sfxVolume),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.music == music &&
      other.sfx == sfx &&
      other.haptics == haptics &&
      other.reducedMotion == reducedMotion &&
      other.musicVolume == musicVolume &&
      other.sfxVolume == sfxVolume;

  @override
  int get hashCode =>
      Object.hash(music, sfx, haptics, reducedMotion, musicVolume, sfxVolume);
}

/// Daily challenge progress (filled in by Phase 12).
@immutable
class DailyProgress {
  const DailyProgress({
    this.date,
    this.challengeId,
    this.progress = 0,
    this.completed = false,
    this.claimed = false,
  });

  /// Local calendar day this progress belongs to, `yyyy-mm-dd`.
  final String? date;
  final String? challengeId;
  final int progress;
  final bool completed;
  final bool claimed;

  Map<String, Object?> toJson() => {
    'date': date,
    'challengeId': challengeId,
    'progress': progress,
    'completed': completed,
    'claimed': claimed,
  };

  factory DailyProgress.fromJson(Object? json) {
    final m = _map(json);
    return DailyProgress(
      date: m['date'] is String ? m['date']! as String : null,
      challengeId: m['challengeId'] is String
          ? m['challengeId']! as String
          : null,
      progress: _int(m['progress'], 0),
      completed: _bool(m['completed'], false),
      claimed: _bool(m['claimed'], false),
    );
  }
}

/// Daily login streak (7-day cycle, Phase 12).
@immutable
class StreakData {
  const StreakData({this.count = 0, this.lastClaimDate});

  final int count;
  final String? lastClaimDate;

  Map<String, Object?> toJson() => {
    'count': count,
    'lastClaimDate': lastClaimDate,
  };

  factory StreakData.fromJson(Object? json) {
    final m = _map(json);
    return StreakData(
      count: _int(m['count'], 0),
      lastClaimDate: m['lastClaimDate'] is String
          ? m['lastClaimDate']! as String
          : null,
    );
  }
}

/// Lifetime numbers (achievements, results, analytics).
@immutable
class LifetimeStats {
  const LifetimeStats({
    this.gamesPlayed = 0,
    this.totalMerges = 0,
    this.totalDrops = 0,
    this.totalCoinsEarned = 0,
    this.bestCombo = 0,
    this.highestLevel = 0,
  });

  final int gamesPlayed;
  final int totalMerges;
  final int totalDrops;
  final int totalCoinsEarned;
  final int bestCombo;
  final int highestLevel;

  LifetimeStats copyWith({
    int? gamesPlayed,
    int? totalMerges,
    int? totalDrops,
    int? totalCoinsEarned,
    int? bestCombo,
    int? highestLevel,
  }) => LifetimeStats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    totalMerges: totalMerges ?? this.totalMerges,
    totalDrops: totalDrops ?? this.totalDrops,
    totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
    bestCombo: bestCombo ?? this.bestCombo,
    highestLevel: highestLevel ?? this.highestLevel,
  );

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'totalMerges': totalMerges,
    'totalDrops': totalDrops,
    'totalCoinsEarned': totalCoinsEarned,
    'bestCombo': bestCombo,
    'highestLevel': highestLevel,
  };

  factory LifetimeStats.fromJson(Object? json) {
    final m = _map(json);
    return LifetimeStats(
      gamesPlayed: _int(m['gamesPlayed'], 0),
      totalMerges: _int(m['totalMerges'], 0),
      totalDrops: _int(m['totalDrops'], 0),
      totalCoinsEarned: _int(m['totalCoinsEarned'], 0),
      bestCombo: _int(m['bestCombo'], 0),
      highestLevel: _int(m['highestLevel'], 0),
    );
  }
}

/// Everything the game saves, as one immutable, versioned document.
///
/// Parsing is deliberately forgiving: unknown fields are ignored, missing
/// or wrongly-typed fields fall back to defaults, and numbers are clamped
/// to sane ranges. A save from a newer app version therefore still loads
/// (minus the fields this version doesn't know), and a half-written or
/// hand-edited file can't crash the game.
@immutable
class SaveData {
  const SaveData({
    this.bestScore = 0,
    this.coins = 0,
    this.powerUps = const {},
    this.unlockedLevels = const {},
    this.seenLevels = const {},
    this.ownedCosmetics = const {},
    this.equippedJar,
    this.equippedScene,
    this.adsRemoved = false,
    this.settings = const GameSettings(),
    this.tutorialCompleted = false,
    this.daily = const DailyProgress(),
    this.streak = const StreakData(),
    this.achievements = const {},
    this.stats = const LifetimeStats(),
  });

  /// Current schema version written by this build. Bump it (and add a
  /// migration step in SaveStore) whenever the meaning of a field changes.
  static const int schemaVersion = 2;

  /// Power-ups a brand-new player starts with.
  static const int starterPowerUps = 3;

  /// Caps that keep corrupted or exploited saves sane.
  static const int maxCoins = 99999999;
  static const int maxPowerUps = 99;

  final int bestScore;
  final int coins;
  final Map<PowerUp, int> powerUps;

  /// Creature levels the player has created at least once (Collection).
  final Set<int> unlockedLevels;

  /// Unlocked levels the player has already looked at in the Collection;
  /// the rest show a "NEW" tag. (Added in schema v2.)
  final Set<int> seenLevels;

  /// Bought cosmetic ids (jar skins, backgrounds). Free defaults are owned
  /// implicitly and not stored.
  final Set<String> ownedCosmetics;

  /// Equipped cosmetic ids; null = the free default.
  final String? equippedJar;
  final String? equippedScene;

  /// "Remove Ads" purchased (non-consumable, restorable).
  final bool adsRemoved;

  /// Unlocked but not yet seen in the Collection.
  Set<int> get newLevels => unlockedLevels.difference(seenLevels);
  final GameSettings settings;
  final bool tutorialCompleted;
  final DailyProgress daily;
  final StreakData streak;

  /// Ids of unlocked achievements.
  final Set<String> achievements;
  final LifetimeStats stats;

  /// A first-launch save: starter power-ups, nothing unlocked.
  static SaveData fresh() =>
      SaveData(powerUps: {for (final p in PowerUp.values) p: starterPowerUps});

  int powerUpCount(PowerUp p) => powerUps[p] ?? 0;

  SaveData copyWith({
    int? bestScore,
    int? coins,
    Map<PowerUp, int>? powerUps,
    Set<int>? unlockedLevels,
    Set<int>? seenLevels,
    Set<String>? ownedCosmetics,
    String? equippedJar,
    String? equippedScene,
    bool? adsRemoved,
    GameSettings? settings,
    bool? tutorialCompleted,
    DailyProgress? daily,
    StreakData? streak,
    Set<String>? achievements,
    LifetimeStats? stats,
  }) => SaveData(
    bestScore: bestScore ?? this.bestScore,
    coins: coins ?? this.coins,
    powerUps: powerUps ?? this.powerUps,
    unlockedLevels: unlockedLevels ?? this.unlockedLevels,
    seenLevels: seenLevels ?? this.seenLevels,
    ownedCosmetics: ownedCosmetics ?? this.ownedCosmetics,
    equippedJar: equippedJar ?? this.equippedJar,
    equippedScene: equippedScene ?? this.equippedScene,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    settings: settings ?? this.settings,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    daily: daily ?? this.daily,
    streak: streak ?? this.streak,
    achievements: achievements ?? this.achievements,
    stats: stats ?? this.stats,
  );

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'bestScore': bestScore,
    'coins': coins,
    'powerUps': {for (final e in powerUps.entries) e.key.name: e.value},
    'unlockedLevels': (unlockedLevels.toList()..sort()),
    'seenLevels': (seenLevels.toList()..sort()),
    'ownedCosmetics': (ownedCosmetics.toList()..sort()),
    'equippedJar': equippedJar,
    'equippedScene': equippedScene,
    'adsRemoved': adsRemoved,
    'settings': settings.toJson(),
    'tutorialCompleted': tutorialCompleted,
    'daily': daily.toJson(),
    'streak': streak.toJson(),
    'achievements': (achievements.toList()..sort()),
    'stats': stats.toJson(),
  };

  factory SaveData.fromJson(Map<String, Object?> json) {
    final pu = _map(json['powerUps']);
    final ach = json['achievements'];
    return SaveData(
      bestScore: _int(json['bestScore'], 0),
      coins: _int(json['coins'], 0, max: maxCoins),
      powerUps: {
        for (final p in PowerUp.values)
          p: _int(pu[p.name], starterPowerUps, max: maxPowerUps),
      },
      unlockedLevels: _levels(json['unlockedLevels']),
      seenLevels: _levels(json['seenLevels']),
      ownedCosmetics: _strings(json['ownedCosmetics']),
      equippedJar: json['equippedJar'] is String
          ? json['equippedJar']! as String
          : null,
      equippedScene: json['equippedScene'] is String
          ? json['equippedScene']! as String
          : null,
      adsRemoved: _bool(json['adsRemoved'], false),
      settings: GameSettings.fromJson(json['settings']),
      tutorialCompleted: _bool(json['tutorialCompleted'], false),
      daily: DailyProgress.fromJson(json['daily']),
      streak: StreakData.fromJson(json['streak']),
      achievements: {
        if (ach is List)
          for (final a in ach)
            if (a is String) a,
      },
      stats: LifetimeStats.fromJson(json['stats']),
    );
  }

  @override
  String toString() =>
      'SaveData(best: $bestScore, coins: $coins, powerUps: $powerUps, '
      'unlocked: $unlockedLevels, games: ${stats.gamesPlayed})';
}

// --- Tolerant field readers -------------------------------------------------

Map<String, Object?> _map(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};

int _int(Object? v, int fallback, {int max = 0x7fffffff}) {
  final n = v is int ? v : (v is double && v.isFinite ? v.round() : null);
  return n == null ? fallback : n.clamp(0, max);
}

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

Set<String> _strings(Object? v) => {
  if (v is List)
    for (final x in v)
      if (x is String) x,
};

Set<int> _levels(Object? v) => {
  if (v is List)
    for (final l in v)
      if (l is int && l >= 1 && l <= 12) l,
};

double _unit(Object? v, double fallback) =>
    v is num && v.isFinite ? v.toDouble().clamp(0.0, 1.0) : fallback;
