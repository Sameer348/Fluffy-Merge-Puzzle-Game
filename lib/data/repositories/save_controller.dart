import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/models/power_up.dart';
import '../local/preferences_provider.dart';
import '../local/save_data.dart';
import '../local/save_store.dart';

/// End-of-run numbers folded into lifetime stats.
class RunStats {
  const RunStats({
    required this.merges,
    required this.drops,
    required this.coinsEarned,
    required this.bestCombo,
    required this.highestLevel,
  });

  final int merges;
  final int drops;
  final int coinsEarned;
  final int bestCombo;
  final int highestLevel;
}

/// The single source of truth for saved progress. Every change goes
/// through here: state updates immediately (widgets rebuild), then the
/// versioned document is queued to disk.
class SaveController extends Notifier<SaveData> {
  late SaveStore _store;

  @override
  SaveData build() {
    _store = ref.watch(saveStoreProvider);
    return _store.load();
  }

  void _set(SaveData next) {
    state = next;
    _store.save(next);
  }

  /// Current save, for code that holds the controller but not a `ref`
  /// (e.g. a screen's dispose).
  SaveData get current => state;

  /// Completes when all pending writes are on disk.
  Future<void> flush() => _store.flush();

  // --- Runs ----------------------------------------------------------------

  /// Banks a run's progress so far: raises the best score if [score] beats
  /// it and adds [coinsDelta] (coins earned since the last bank). Safe to
  /// call several times per run (e.g. when the app is backgrounded, then
  /// again at game over), so a run killed from the app switcher keeps what
  /// it earned.
  void bankRun({required int score, required int coinsDelta}) {
    final s = state;
    if (score <= s.bestScore && coinsDelta <= 0) return;
    _set(
      s.copyWith(
        bestScore: score > s.bestScore ? score : s.bestScore,
        coins: (s.coins + (coinsDelta > 0 ? coinsDelta : 0)).clamp(
          0,
          SaveData.maxCoins,
        ),
      ),
    );
  }

  /// Folds a finished run into lifetime stats (once per run).
  void finishRun(RunStats run) {
    final st = state.stats;
    _set(
      state.copyWith(
        stats: st.copyWith(
          gamesPlayed: st.gamesPlayed + 1,
          totalMerges: st.totalMerges + run.merges,
          totalDrops: st.totalDrops + run.drops,
          totalCoinsEarned: st.totalCoinsEarned + run.coinsEarned,
          bestCombo: run.bestCombo > st.bestCombo ? run.bestCombo : null,
          highestLevel: run.highestLevel > st.highestLevel
              ? run.highestLevel
              : null,
        ),
      ),
    );
  }

  // --- Coins ---------------------------------------------------------------

  void addCoins(int amount) {
    if (amount <= 0) return;
    _set(
      state.copyWith(
        coins: (state.coins + amount).clamp(0, SaveData.maxCoins),
        stats: state.stats.copyWith(
          totalCoinsEarned: state.stats.totalCoinsEarned + amount,
        ),
      ),
    );
  }

  /// Spends coins if there are enough. Returns false (no change) if not.
  bool spendCoins(int amount) {
    if (amount < 0 || state.coins < amount) return false;
    _set(state.copyWith(coins: state.coins - amount));
    return true;
  }

  // --- Power-ups -----------------------------------------------------------

  /// Uses one if available. Returns false (and changes nothing) at 0.
  bool consumePowerUp(PowerUp p) {
    final have = state.powerUpCount(p);
    if (have <= 0) return false;
    _set(state.copyWith(powerUps: {...state.powerUps, p: have - 1}));
    return true;
  }

  void addPowerUp(PowerUp p, [int amount = 1]) {
    if (amount <= 0) return;
    final next = (state.powerUpCount(p) + amount).clamp(
      0,
      SaveData.maxPowerUps,
    );
    _set(state.copyWith(powerUps: {...state.powerUps, p: next}));
  }

  // --- Collection, tutorial, settings, achievements ------------------------

  /// Marks a creature level as discovered. Returns true the first time.
  bool unlockLevel(int level) {
    if (level < 1 || level > 12 || state.unlockedLevels.contains(level)) {
      return false;
    }
    _set(state.copyWith(unlockedLevels: {...state.unlockedLevels, level}));
    return true;
  }

  // --- Shop ----------------------------------------------------------------

  void addCosmetic(String id) {
    if (state.ownedCosmetics.contains(id)) return;
    _set(state.copyWith(ownedCosmetics: {...state.ownedCosmetics, id}));
  }

  void equipJar(String id) => _set(state.copyWith(equippedJar: id));

  void equipScene(String id) => _set(state.copyWith(equippedScene: id));

  void setAdsRemoved() {
    if (!state.adsRemoved) _set(state.copyWith(adsRemoved: true));
  }

  /// Clears the Collection's NEW tags.
  void markLevelsSeen() {
    if (state.newLevels.isEmpty) return;
    _set(state.copyWith(seenLevels: {...state.unlockedLevels}));
  }

  void completeTutorial() {
    if (!state.tutorialCompleted) {
      _set(state.copyWith(tutorialCompleted: true));
    }
  }

  void updateSettings(GameSettings Function(GameSettings) change) {
    final next = change(state.settings);
    if (next != state.settings) _set(state.copyWith(settings: next));
  }

  /// Returns true the first time [id] is unlocked.
  bool unlockAchievement(String id) {
    if (state.achievements.contains(id)) return false;
    _set(state.copyWith(achievements: {...state.achievements, id}));
    return true;
  }

  void setDaily(DailyProgress daily) => _set(state.copyWith(daily: daily));

  void setStreak(StreakData streak) => _set(state.copyWith(streak: streak));
}

final saveStoreProvider = Provider<SaveStore>(
  (ref) => SaveStore(ref.watch(sharedPreferencesProvider)),
);

final saveProvider = NotifierProvider<SaveController, SaveData>(
  SaveController.new,
);

/// Current power-up stock (rebuilds only when counts change).
final powerUpCountsProvider = Provider<Map<PowerUp, int>>(
  (ref) => ref.watch(saveProvider.select((s) => s.powerUps)),
);
