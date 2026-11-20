import '../../game/models/power_up.dart';

/// Pre-v1 SharedPreferences keys. Only [SaveStore] reads these, once, to
/// migrate old installs into the versioned save; nothing writes them.
abstract final class SaveKeys {
  static const bestScore = 'best_score';
  static const coins = 'coins';

  /// One int per power-up: `powerup_sweep`, `powerup_pop`, …
  static String powerUp(PowerUp p) => 'powerup_${p.name}';
}
