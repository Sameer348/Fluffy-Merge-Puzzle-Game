import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/models/power_up.dart';
import '../local/preferences_provider.dart';
import '../local/save_keys.dart';

/// Power-up stock, persisted per power-up.
///
/// New players start with [starterCount] of each. Counts never go below 0.
/// State is an immutable map so Riverpod rebuilds only on real changes.
class PowerUpInventory extends Notifier<Map<PowerUp, int>> {
  static const int starterCount = 3;

  /// Upper bound so a bug or exploit can't create absurd stockpiles.
  static const int maxCount = 99;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Map<PowerUp, int> build() => {
    for (final p in PowerUp.values)
      p: _prefs.getInt(SaveKeys.powerUp(p)) ?? starterCount,
  };

  int count(PowerUp p) => state[p] ?? 0;

  /// Uses one if available. Returns false (and changes nothing) at 0.
  bool consume(PowerUp p) {
    final have = count(p);
    if (have <= 0) return false;
    _set(p, have - 1);
    return true;
  }

  void add(PowerUp p, [int amount = 1]) {
    if (amount <= 0) return;
    _set(p, (count(p) + amount).clamp(0, maxCount));
  }

  void _set(PowerUp p, int value) {
    state = {...state, p: value};
    // Cache updates synchronously; the disk write finishes in background.
    _prefs.setInt(SaveKeys.powerUp(p), value);
  }
}

final powerUpInventoryProvider =
    NotifierProvider<PowerUpInventory, Map<PowerUp, int>>(PowerUpInventory.new);
