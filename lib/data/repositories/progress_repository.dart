import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/preferences_provider.dart';
import '../local/save_keys.dart';

/// Result of recording a finished (or abandoned) run.
class RunRecord {
  const RunRecord({required this.isNewBest, required this.bestScore});
  final bool isNewBest;
  final int bestScore;
}

/// Player progress that survives app restarts: best score and coin wallet.
///
/// Backed by SharedPreferences (reads are synchronous after startup).
/// Phase 11 moves this onto the versioned save model without changing
/// callers.
class ProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  int get bestScore => _prefs.getInt(SaveKeys.bestScore) ?? 0;
  int get coins => _prefs.getInt(SaveKeys.coins) ?? 0;

  /// Saves a run's score (if it's a new best) and adds its coins to the
  /// wallet. Safe to call with zeros.
  Future<RunRecord> recordRun({
    required int score,
    required int coinsEarned,
  }) async {
    final best = bestScore;
    final isNewBest = score > best;
    if (isNewBest) await _prefs.setInt(SaveKeys.bestScore, score);
    if (coinsEarned > 0) {
      await _prefs.setInt(SaveKeys.coins, coins + coinsEarned);
    }
    return RunRecord(isNewBest: isNewBest, bestScore: isNewBest ? score : best);
  }

  /// Adds coins to the wallet (e.g. a rewarded-ad bonus).
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await _prefs.setInt(SaveKeys.coins, coins + amount);
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(sharedPreferencesProvider)),
);
