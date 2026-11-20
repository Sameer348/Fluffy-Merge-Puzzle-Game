import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/models/power_up.dart';
import 'save_data.dart';
import 'save_keys.dart';

/// Where a loaded save came from (useful for tests and diagnostics).
enum SaveSource { primary, backup, legacy, fresh }

/// Reads and writes the versioned [SaveData] document.
///
/// * One JSON document under [primaryKey], so a save is all-or-nothing.
/// * After every successful load the document is copied to [backupKey]; a
///   corrupt primary falls back to it (the corrupt text is kept under
///   [corruptKey] for support, never silently thrown away).
/// * Pre-v1 builds stored separate keys (`best_score`, `coins`,
///   `powerup_*`); they're migrated once, then removed.
/// * Fields this build doesn't know (written by a newer version) are kept
///   and written back untouched.
/// * Writes are queued so they reach disk in order. SharedPreferences
///   updates its in-memory cache synchronously, so reads right after a
///   write already see the new value.
class SaveStore {
  SaveStore(this._prefs);

  final SharedPreferences _prefs;

  static const primaryKey = 'save_v1';
  static const backupKey = 'save_v1_backup';
  static const corruptKey = 'save_v1_corrupt';

  /// Upgrade steps: `migrations[n]` turns a version-n document into n+1.
  /// Add entries here when [SaveData.schemaVersion] is bumped.
  static final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
  migrations = {
    // v1 → v2: Collection "seen" tracking. Everything already unlocked
    // counts as seen, so existing players don't get a wall of NEW tags.
    1: (json) => {...json, 'seenLevels': json['unlockedLevels'] ?? const []},
  };

  Map<String, Object?> _unknown = const {};
  bool _upgraded = false;
  Future<void> _queue = Future.value();

  SaveSource? _source;
  SaveSource? get lastSource => _source;

  static const _knownKeys = {
    'version',
    'bestScore',
    'coins',
    'powerUps',
    'unlockedLevels',
    'seenLevels',
    'ownedCosmetics',
    'equippedJar',
    'equippedScene',
    'adsRemoved',
    'settings',
    'tutorialCompleted',
    'daily',
    'streak',
    'achievements',
    'stats',
  };

  SaveData load() {
    final raw = _prefs.getString(primaryKey);
    if (raw != null) {
      final data = _tryParse(raw);
      if (data != null) {
        _source = SaveSource.primary;
        _prefs.setString(backupKey, raw);
        // An older schema was upgraded in memory: write it back now so the
        // upgrade runs once, not on every launch.
        if (_upgraded) save(data);
        return data;
      }
      debugPrint('SaveStore: primary save unreadable, trying backup');
      _prefs.setString(corruptKey, raw);
      final backup = _prefs.getString(backupKey);
      final restored = backup == null ? null : _tryParse(backup);
      if (restored != null) {
        _source = SaveSource.backup;
        save(restored);
        return restored;
      }
    }

    final legacy = _readLegacy();
    if (legacy != null) {
      _source = SaveSource.legacy;
      save(legacy);
      _clearLegacy();
      return legacy;
    }

    _source = SaveSource.fresh;
    final fresh = SaveData.fresh();
    save(fresh);
    return fresh;
  }

  /// Queues [data] to be written (in order).
  void save(SaveData data) {
    final encoded = jsonEncode({..._unknown, ...data.toJson()});
    _queue = _queue.then((_) => _prefs.setString(primaryKey, encoded));
  }

  /// Completes when every queued write has reached SharedPreferences.
  Future<void> flush() => _queue;

  SaveData? _tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      var json = decoded.map((k, v) => MapEntry('$k', v));
      var version = json['version'] is int ? json['version']! as int : 1;
      _upgraded = version < SaveData.schemaVersion;
      while (version < SaveData.schemaVersion) {
        final step = migrations[version];
        if (step != null) json = step(json);
        version++;
      }
      _unknown = {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      };
      return SaveData.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  SaveData? _readLegacy() {
    final best = _prefs.getInt(SaveKeys.bestScore);
    final coins = _prefs.getInt(SaveKeys.coins);
    final pus = {
      for (final p in PowerUp.values) p: _prefs.getInt(SaveKeys.powerUp(p)),
    };
    if (best == null && coins == null && pus.values.every((v) => v == null)) {
      return null;
    }
    final fresh = SaveData.fresh();
    return fresh.copyWith(
      bestScore: (best ?? 0).clamp(0, 0x7fffffff),
      coins: (coins ?? 0).clamp(0, SaveData.maxCoins),
      powerUps: {
        for (final p in PowerUp.values)
          p: (pus[p] ?? SaveData.starterPowerUps).clamp(
            0,
            SaveData.maxPowerUps,
          ),
      },
    );
  }

  void _clearLegacy() {
    _prefs
      ..remove(SaveKeys.bestScore)
      ..remove(SaveKeys.coins);
    for (final p in PowerUp.values) {
      _prefs.remove(SaveKeys.powerUp(p));
    }
  }
}
