import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/save_controller.dart';
import '../../game/fluffy_game.dart';
import '../../game/models/creature_spec.dart';
import '../../game/models/power_up.dart';
import '../../game/models/run_result.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/creature/creature_view.dart';
import '../../widgets/dialogs/cozy_dialog.dart';
import '../../widgets/scene/scene_background.dart';
import '../../core/services/ads/ad_service.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/feedback_service.dart';
import '../../core/utils/clock.dart';
import '../daily_challenge/daily_controller.dart';
import '../daily_challenge/model/daily_challenge.dart';
import 'widgets/game_hud.dart';
import 'widgets/jar_view.dart';
import 'widgets/overflow_warning.dart';
import 'widgets/pause_menu.dart';
import 'widgets/power_up_bar.dart';
import 'widgets/pick_banner.dart';

/// Gameplay screen: storybook meadow, HUD (pause, score, level badge,
/// coins), the glass jar with the live Flame game, and the power-up bar.
///
/// Owns the [FluffyGame] for the run and the power-up flow:
/// * SWEEP — highlight what it would clear → confirm → clear.
/// * SHAKE — immediate.
/// * POP / GROW — enter pick mode (eligible puffs glow, drops are locked)
///   → tap a puff → POP confirms first, GROW applies straight away.
/// A power-up is only spent when its effect actually happens.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with WidgetsBindingObserver {
  FluffyGame? _game;

  /// Saved numbers when the run started (for "new best" and the HUD).
  late int _walletAtStart;
  late int _bestAtStart;

  /// Coins already banked into the save during this run.
  int _coinsBanked = 0;
  bool _finished = false;
  bool _paused = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Leaving the app mid-run (call, home button) opens the pause menu, so
  /// the run waits for the player instead of continuing unseen, and banks
  /// progress so far in case the OS kills the app in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _bank();
      _pause();
    }
  }

  /// POP or GROW while choosing a target; null otherwise.
  PowerUp? _picking;

  /// Captured once: `ref` can't be used in dispose(), where the run is
  /// finished if the screen goes away some other way.
  late final SaveController _save = ref.read(saveProvider.notifier);
  late final DailyController _daily = ref.read(dailyControllerProvider);
  late final FeedbackService _feedback = ref.read(feedbackProvider);
  late final AdService _ads = ref.read(adServiceProvider);
  late final AnalyticsService _analytics = ref.read(analyticsProvider);
  late final InterstitialPolicy _policy = ref.read(interstitialPolicyProvider);
  late final DateTime Function() _now = ref.read(clockProvider);

  /// Set when the run finishes: an interstitial may be shown on leaving.
  bool _interstitialDue = false;

  /// Power-ups already given for a rewarded ad this run (once each).
  final Set<PowerUp> _freeClaimed = {};

  /// Today's challenge as of the run's start, its stored progress then
  /// (so repeated updates never double-count), and whether it's done.
  late final DailyChallenge _challenge;
  late final int _dailyBaseline;
  bool _dailyDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      final saved = ref.read(saveProvider);
      _save; // capture while ref is usable
      _feedback;
      _ads;
      _analytics;
      _policy;
      _now;
      _challenge = _daily.today();
      final daily = _daily.progressFor(_challenge);
      _dailyBaseline = daily.progress;
      _dailyDone = daily.completed;
      _walletAtStart = saved.coins;
      _bestAtStart = saved.bestScore;
      _game =
          FluffyGame(
              reduceMotion: reduceMotion(context),
              bestScore: saved.bestScore,
            )
            ..addPowerUpEarnedListener((p) {
              _save.addPowerUp(p);
              _feedback.reward();
            })
            ..addLevelReachedListener(_onLevelReached)
            ..addGameOverListener(_onGameOver);
      final game = _game!;
      _analytics.log(AnalyticsEvent.gameStarted, {
        'best_score': saved.bestScore,
        'games_played': saved.stats.gamesPlayed,
      });
      game
        ..addMergeListener((_) => _checkDaily())
        ..addScoredMergeListener((a) {
          _feedback.merge(
            level: a.event.fromLevel,
            combo: a.combo,
            rainbow: a.event.isMaxClear,
          );
          _analytics.log(AnalyticsEvent.mergeCreated, {
            'level': a.event.resultLevel ?? 0,
            'combo': a.combo,
          });
          if (a.combo >= 3) {
            _analytics.log(AnalyticsEvent.comboCreated, {'combo': a.combo});
          }
        })
        // Impacts above ~2 m/s are audible; ~12 m/s is a full thump.
        ..addImpactListener((v) => _feedback.bounce((v - 2) / 10))
        ..drops.addListener(_checkDaily)
        ..drops.addListener(_feedback.drop);
    }
  }

  RunSnapshot _snapshot() {
    final g = _game!;
    return RunSnapshot(
      score: g.scoring.score.value,
      highestLevel: g.highestLevel.value,
      merges: g.merges.value,
      bestCombo: g.scoring.bestCombo,
      drops: g.drops.value,
    );
  }

  /// Live check after every merge/drop: celebrate the moment today's
  /// challenge is done (saved immediately so it can't be lost).
  void _checkDaily() {
    if (_dailyDone) return;
    final done = _daily.applyRun(
      _challenge,
      _dailyBaseline,
      _snapshot(),
      persistProgress: false,
    );
    if (!done) return;
    _dailyDone = true;
    _feedback.reward();
    _analytics.log(AnalyticsEvent.dailyChallengeCompleted, {
      'kind': _challenge.kind.name,
      'target': _challenge.target,
    });
    final game = _game!;
    if (!game.isLoaded) return;
    game.showPopup(
      'Daily complete!',
      sub: 'Claim it on the Daily screen',
      color: AppColors.sunshineDeep,
      at: Vector2(game.size.x / 2, game.size.y * 0.36),
      scale: 1.1,
      lifetime: 2.0,
    );
  }

  /// First time ever a creature level appears: unlock it in the
  /// Collection and celebrate (levels above the starting few only, so the
  /// first run isn't a wall of popups).
  void _onLevelReached(int level) {
    final isNew = _save.unlockLevel(level);
    final game = _game;
    if (!isNew || game == null || level <= 3 || !game.isLoaded) return;
    game.showPopup(
      'New puff!',
      sub: CreatureCatalog.byLevel(level).name,
      color: AppColors.candyPink,
      at: Vector2(game.size.x / 2, game.size.y * 0.32),
      scale: 1.1,
      lifetime: 1.6,
    );
  }

  /// Banks best score and coins earned so far. Called when the app is
  /// backgrounded and when the run ends; only the not-yet-banked coins are
  /// added, so calling it repeatedly never double-counts.
  void _bank() {
    final game = _game;
    if (game == null) return;
    final s = game.scoring;
    _save.bankRun(
      score: s.score.value,
      coinsDelta: s.coins.value - _coinsBanked,
    );
    _coinsBanked = s.coins.value;
    _daily.applyRun(_challenge, _dailyBaseline, _snapshot());
  }

  /// Ends the run in the save: final bank plus lifetime stats (once).
  void _finishRun() {
    if (_finished) return;
    _finished = true;
    _bank();
    final game = _game!;
    _save.finishRun(
      RunStats(
        merges: game.merges.value,
        drops: game.drops.value,
        coinsEarned: game.scoring.coins.value,
        bestCombo: game.scoring.bestCombo,
        highestLevel: game.highestLevel.value,
      ),
    );
    final saved = _save.current;
    _interstitialDue = _policy.onRunFinished(
      adsRemoved: saved.adsRemoved,
      lifetimeGames: saved.stats.gamesPlayed,
      now: _now(),
    );
    _analytics.log(AnalyticsEvent.gameOver, {
      'score': game.scoring.score.value,
      'level': game.highestLevel.value,
      'merges': game.merges.value,
      'seconds': game.clock.round(),
      'continued': game.revives,
      'ended_by': game.isGameOver ? 'overflow' : 'quit',
    });
  }

  /// Shows the interstitial the policy asked for (if any) before leaving
  /// mid-run via the pause menu.
  Future<void> _maybeInterstitial() async {
    if (_interstitialDue && _ads.interstitialAvailable) {
      _interstitialDue = false;
      await _ads.showInterstitial();
    }
  }

  /// Once per run: watch an ad to clear the top of the jar and keep going.
  /// Returns true if the run continues.
  Future<bool> _offerContinue() async {
    final game = _game!;
    if (game.revives > 0 || !_ads.rewardedAvailable || !mounted) return false;
    final ok = await showCozyConfirm(
      context,
      title: 'Keep going?',
      message:
          'Watch a short ad to clear the top of the jar and keep playing. '
          'Once per run.',
      confirmLabel: 'Watch ad',
      cancelLabel: 'No thanks',
      preview: const Icon(
        Icons.ondemand_video_rounded,
        size: 56,
        color: AppColors.candyPink,
      ),
      confirmColor: CandyColor.green,
    );
    if (!ok || !mounted) return false;
    final earned = await _ads.showRewarded(RewardPlacement.continueRun);
    if (!earned || !mounted) return false;
    _analytics.log(AnalyticsEvent.rewardedAdWatched, {
      'placement': RewardPlacement.continueRun.id,
    });
    game.revive();
    _feedback.reward();
    return true;
  }

  Future<void> _onGameOver() async {
    _feedback.gameOver();
    if (_leaving || !mounted) return;
    _leaving = true;
    _stopPicking();
    final game = _game!;
    if (await _offerContinue()) {
      _leaving = false;
      return;
    }
    if (!mounted) return;
    _finishRun();
    final score = game.scoring.score.value;
    final result = RunResult(
      score: score,
      bestScore: score > _bestAtStart ? score : _bestAtStart,
      isNewBest: score > _bestAtStart,
      highestLevel: game.highestLevel.value,
      coinsEarned: game.scoring.coins.value,
      merges: game.merges.value,
      drops: game.drops.value,
      bestCombo: game.scoring.bestCombo,
      seconds: game.clock,
      interstitialDue: _interstitialDue,
    );
    await Navigator.of(context)
        .pushReplacementNamed(AppRoutes.results, arguments: result);
  }

  /// Pause button, system back, or app backgrounded.
  Future<void> _pause() async {
    final game = _game;
    if (game == null || _paused || _leaving || game.isGameOver || !mounted) {
      return;
    }
    _paused = true;
    _stopPicking();
    game.pauseEngine();
    final choice = await showPauseMenu(context);
    _paused = false;
    if (!mounted) return;
    switch (choice) {
      case PauseChoice.resume:
        game.resumeEngine();
      case PauseChoice.restart:
        _leaving = true;
        _finishRun();
        await _maybeInterstitial();
        if (mounted) {
          await Navigator.of(context).pushReplacementNamed(AppRoutes.game);
        }
      case PauseChoice.home:
        _leaving = true;
        _finishRun();
        await _maybeInterstitial();
        if (mounted) Navigator.of(context).pop();
    }
  }

  /// "+" next to coins: open the shop with the game paused.
  Future<void> _openShop() async {
    final game = _game!;
    _stopPicking();
    game.pauseEngine();
    await Navigator.of(context).pushNamed(AppRoutes.shop);
    if (mounted) game.resumeEngine();
  }

  // ---------------------------------------------------------------------------
  // Power-ups

  Future<void> _usePowerUp(PowerUp p) async {
    final game = _game!;
    if (_picking == p) {
      _stopPicking(); // tapping the active button again cancels
      return;
    }
    _stopPicking();
    if (ref.read(saveProvider).powerUpCount(p) <= 0) {
      if (!await _offerFreePowerUp(p)) _toast(_howToEarn(p));
      return;
    }
    switch (p) {
      case PowerUp.shake:
        if (_save.consumePowerUp(p)) {
          game.powerUps.shake();
          _used(p);
        }
      case PowerUp.sweep:
        await _sweep();
      case PowerUp.pop:
      case PowerUp.grow:
        setState(() => _picking = p);
        game.inputLocked = true;
        game.powerUps.highlight((c) => game.powerUps.canTarget(p, c));
    }
  }

  Future<void> _sweep() async {
    final game = _game!;
    final targets = game.powerUps.sweepTargets();
    if (targets.isEmpty) {
      _toast('The jar is empty, nothing to sweep!');
      return;
    }
    final ids = {for (final c in targets) c.id};
    game.powerUps.highlight((c) => ids.contains(c.id));
    final n = targets.length;
    final ok = await _confirmPaused(
      title: 'Sweep',
      message: 'Sweep away $n small puff${n == 1 ? '' : 's'}?',
      confirmLabel: 'Sweep',
    );
    game.powerUps.highlight(null);
    if (ok && _save.consumePowerUp(PowerUp.sweep)) {
      game.powerUps.sweep();
      _used(PowerUp.sweep);
    }
  }

  Future<void> _onPick(Vector2 px) async {
    final p = _picking;
    if (p == null) return;
    final game = _game!;
    final c = game.powerUps.creatureAtPixel(px, forPowerUp: p);
    if (c == null) return; // missed: stay in pick mode
    if (p == PowerUp.grow) {
      if (game.powerUps.grow(c)) {
        _save.consumePowerUp(p);
        _used(p);
      }
      _stopPicking();
      return;
    }
    // POP is destructive: show exactly which puff, then confirm.
    game.powerUps.highlight((x) => x.id == c.id);
    final ok = await _confirmPaused(
      title: 'Pop',
      message: 'Pop this ${c.spec.name}?',
      confirmLabel: 'Pop!',
      preview: CreatureView(spec: c.spec, size: 84),
    );
    if (ok && game.powerUps.pop(c)) {
      _save.consumePowerUp(p);
      _used(p);
    }
    _stopPicking();
  }

  void _used(PowerUp p) {
    _feedback.powerUp();
    _analytics.log(AnalyticsEvent.powerUpUsed, {'type': p.name});
  }

  /// Out of [p]: offer one for a rewarded ad (once per power-up per run).
  /// Returns false if no offer was made (so the "how to earn" tip shows).
  Future<bool> _offerFreePowerUp(PowerUp p) async {
    if (!_ads.rewardedAvailable || _freeClaimed.contains(p)) return false;
    final ok = await _confirmPaused(
      title: 'Free ${p.label}?',
      message: 'Out of ${p.label}s. Watch a short ad to get 1 free!',
      confirmLabel: 'Watch ad',
      cancelLabel: 'No thanks',
      preview: PowerUpIcon(kind: p, size: 64),
      confirmColor: CandyColor.green,
    );
    if (!ok || !mounted) return true;
    final game = _game!;
    game
      ..frozen = true
      ..inputLocked = true;
    final earned = await _ads.showRewarded(RewardPlacement.freePowerUp);
    if (!mounted) return true;
    game
      ..frozen = false
      ..inputLocked = false;
    if (!earned) return true;
    _freeClaimed.add(p);
    _save.addPowerUp(p);
    _feedback.reward();
    _analytics.log(AnalyticsEvent.rewardedAdWatched, {
      'placement': RewardPlacement.freePowerUp.id,
      'power_up': p.name,
    });
    // A popup in the jar, not a snackbar: that would cover the power-up
    // bar right when the player wants to use what they just got.
    if (game.isLoaded) {
      game.showPopup(
        '+1 ${p.label}',
        sub: 'Free power-up!',
        color: AppColors.candyGreenTop,
        at: Vector2(game.size.x / 2, game.size.y * 0.36),
        scale: 1.1,
        lifetime: 1.6,
      );
    }
    return true;
  }

  void _stopPicking() {
    final game = _game;
    if (game == null) return;
    game
      ..inputLocked = false
      ..powerUps.highlight(null);
    if (_picking != null && mounted) setState(() => _picking = null);
  }

  /// Confirm dialog with the game frozen underneath (still drawn, so the
  /// highlighted target stays visible).
  Future<bool> _confirmPaused({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    Widget? preview,
    CandyColor confirmColor = CandyColor.pink,
  }) async {
    final game = _game!;
    game
      ..frozen = true
      ..inputLocked = true;
    final ok = await showCozyConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      preview: preview,
      confirmColor: confirmColor,
    );
    if (mounted) {
      game
        ..frozen = false
        ..inputLocked = _picking != null;
    }
    return ok;
  }

  static String _howToEarn(PowerUp p) {
    final level = FluffyGame.milestoneRewards.entries
        .firstWhere((e) => e.value == p)
        .key;
    final extra = p == PowerUp.shake
        ? ' or a ${FluffyGame.comboRewardAt}x combo'
        : '';
    return 'No ${p.label}s left. Reach Lv. $level$extra in a run to earn one!';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.panelBorder, width: 2),
          ),
          content: Text(
            message,
            style: AppText.body(15, color: AppColors.woodDark),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finishRun(); // fallback if the route went away some other way
    _game?.disposeSession();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Layout

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final counts = ref.watch(powerUpCountsProvider);
    // System back opens the pause menu instead of silently ending the run.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: SceneBackground(variant: SceneVariant.game),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = GameLayout.compute(constraints.biggest);
                  final r = Responsive.of(constraints.biggest);
                  return Stack(
                    children: [
                      Positioned.fromRect(
                        rect: layout.hud,
                        child: GameHud(
                          r: r,
                          game: game,
                          wallet: _walletAtStart,
                          onPause: _pause,
                          onAddCoins: _openShop,
                        ),
                      ),
                      Positioned.fromRect(
                        rect: layout.jar.inflate(kJarRim),
                        child: JarView(
                          game: game,
                          onPick: _picking == null ? null : _onPick,
                        ),
                      ),
                      // Overflow countdown, just under the danger line.
                      Positioned(
                        left: layout.jar.left,
                        right: constraints.maxWidth - layout.jar.right,
                        top: layout.jar.top + layout.jar.height * 0.17,
                        child: Center(
                          child: OverflowWarning(
                            countdown: game.overflowCountdown,
                            scale: r.scale,
                          ),
                        ),
                      ),
                      if (_picking != null)
                        Positioned(
                          left: layout.jar.left,
                          right: constraints.maxWidth - layout.jar.right,
                          // Below the NEXT bubble, over the empty upper jar.
                          top: layout.jar.top + layout.jar.height * 0.17,
                          child: Center(
                            child: PickBanner(
                              text: _picking == PowerUp.pop
                                  ? 'Tap a puff to pop'
                                  : 'Tap a puff to grow',
                              scale: r.scale,
                              onCancel: _stopPicking,
                            ),
                          ),
                        ),
                      Positioned.fromRect(
                        rect: layout.powerBar,
                        child: PowerUpBar(
                          r: r,
                          counts: counts,
                          active: _picking,
                          onUse: _usePowerUp,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
