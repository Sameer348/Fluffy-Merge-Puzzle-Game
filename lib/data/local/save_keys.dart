import '../../game/models/power_up.dart';

/// SharedPreferences keys. Centralised so the Phase 11 versioned save model
/// can migrate them in one place.
abstract final class SaveKeys {
  static const bestScore = 'best_score';
  static const coins = 'coins';

  /// One int per power-up: `powerup_sweep`, `powerup_pop`, …
  static String powerUp(PowerUp p) => 'powerup_${p.name}';
}
