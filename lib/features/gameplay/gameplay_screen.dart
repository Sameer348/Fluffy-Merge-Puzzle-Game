import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/power_up_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../game/fluffy_game.dart';
import '../../game/models/power_up.dart';
import '../../game/models/run_result.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/creature/creature_view.dart';
import '../../widgets/dialogs/cozy_dialog.dart';
import '../../widgets/scene/scene_background.dart';
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
  late ProgressRepository _progress;
  late int _walletAtStart;
  Future<RunRecord>? _record;
  bool _paused = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Leaving the app mid-run (call, home button) opens the pause menu, so
  /// the run waits for the player instead of continuing unseen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  /// POP or GROW while choosing a target; null otherwise.
  PowerUp? _picking;

  PowerUpInventory get _inventory =>
      ref.read(powerUpInventoryProvider.notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      _progress = ref.read(progressRepositoryProvider);
      _walletAtStart = _progress.coins;
      _game =
          FluffyGame(
              reduceMotion: reduceMotion(context),
              bestScore: _progress.bestScore,
            )
            ..addPowerUpEarnedListener((p) => _inventory.add(p))
            ..addGameOverListener(_onGameOver);
    }
  }

  /// Saves best score and coins exactly once per run, however it ends.
  /// SharedPreferences updates its cache synchronously, so readers see the
  /// new values immediately even though the disk write is async.
  Future<RunRecord> _recordRun() {
    final s = _game!.scoring;
    return _record ??= _progress.recordRun(
      score: s.score.value,
      coinsEarned: s.coins.value,
    );
  }

  Future<void> _onGameOver() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _stopPicking();
    final game = _game!;
    final record = await _recordRun();
    if (!mounted) return;
    final result = RunResult(
      score: game.scoring.score.value,
      bestScore: record.bestScore,
      isNewBest: record.isNewBest,
      highestLevel: game.highestLevel.value,
      coinsEarned: game.scoring.coins.value,
      merges: game.merges.value,
      drops: game.drops.value,
      bestCombo: game.scoring.bestCombo,
      seconds: game.clock,
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
        await _recordRun();
        if (mounted) {
          await Navigator.of(context).pushReplacementNamed(AppRoutes.game);
        }
      case PauseChoice.home:
        _leaving = true;
        await _recordRun();
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
    if (_inventory.count(p) <= 0) {
      _toast(_howToEarn(p));
      return;
    }
    switch (p) {
      case PowerUp.shake:
        if (_inventory.consume(p)) game.powerUps.shake();
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
    if (ok && _inventory.consume(PowerUp.sweep)) game.powerUps.sweep();
  }

  Future<void> _onPick(Vector2 px) async {
    final p = _picking;
    if (p == null) return;
    final game = _game!;
    final c = game.powerUps.creatureAtPixel(px, forPowerUp: p);
    if (c == null) return; // missed: stay in pick mode
    if (p == PowerUp.grow) {
      if (game.powerUps.grow(c)) _inventory.consume(p);
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
    if (ok && game.powerUps.pop(c)) _inventory.consume(p);
    _stopPicking();
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
    Widget? preview,
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
      preview: preview,
      confirmColor: CandyColor.pink,
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
    _recordRun(); // fallback if the route went away some other way
    _game?.disposeSession();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Layout

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final counts = ref.watch(powerUpInventoryProvider);
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
