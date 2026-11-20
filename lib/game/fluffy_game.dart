import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/game_constants.dart';
import 'components/creature_component.dart';
import 'components/dropper_component.dart';
import 'components/danger_line_component.dart';
import 'components/floating_text_component.dart';
import 'components/particle_system.dart';
import 'models/creature_spec.dart';
import 'models/merge_event.dart';
import 'models/power_up.dart';
import 'physics/jar_walls.dart';
import 'physics/jar_world.dart';
import 'physics/physics_config.dart';
import 'systems/drop_geometry.dart';
import 'systems/merge_detector.dart';
import 'systems/merge_math.dart';
import 'systems/overflow_timer.dart';
import 'systems/power_up_system.dart';
import 'systems/score_system.dart';
import 'systems/spawn_queue.dart';

/// The Flame + Forge2D game that lives inside the jar.
///
/// World coordinates are meters: origin at the jar's top-left, x → right,
/// y → down, jar = [GameConstants.worldWidth] × [GameConstants.worldHeight].
/// The GameWidget is sized to the jar by [GameLayout], so the camera only
/// sets meters-to-pixels.
///
/// Physics runs at a fixed step in [JarWorld]; the native Box2D world is
/// freed in [disposeSession].
///
/// UI talks to the game through plain methods ([aimAtPixel], [drop]) and
/// listens to [ValueNotifier]s; Flutter state never leaks into components.
class FluffyGame extends Forge2DGame<JarWorld> implements TouchListener {
  FluffyGame({int? seed, bool reduceMotion = false, int bestScore = 0})
    : this._(SpawnQueue(seed: seed), seed ?? 0, reduceMotion, bestScore);

  // The first creature is taken from the queue up front so [nextLevel]
  // already holds its final value before any widget listens. (onLoad runs
  // during the GameWidget's build; notifying there would rebuild listeners
  // mid-build.)
  FluffyGame._(this.spawner, this._seed, this.reduceMotion, int bestScore)
    : _firstLevel = spawner.take(),
      nextLevel = ValueNotifier(spawner.peek),
      scoring = ScoreSystem(bestAtStart: bestScore),
      super(world: JarWorld());

  /// Score, combo and coins for this run (HUD binds to its notifiers).
  final ScoreSystem scoring;

  /// Popups currently on screen (capped so bursts never pile up).
  final List<FloatingTextComponent> _popups = [];
  static const int _maxPopups = 5;

  final SpawnQueue spawner;
  final bool reduceMotion;
  final int _seed;

  /// Seeded so a run with the same seed and inputs replays identically.
  late final math.Random _dropJitter = math.Random(_seed ^ 0x5eed);
  final int _firstLevel;

  /// Level shown in the "NEXT" bubble.
  final ValueNotifier<int> nextLevel;

  /// Total creatures dropped this run.
  final ValueNotifier<int> drops = ValueNotifier(0);

  /// Total merges this run (max-level clears included).
  final ValueNotifier<int> merges = ValueNotifier(0);

  /// Highest creature level that has appeared this run.
  final ValueNotifier<int> highestLevel = ValueNotifier(1);

  /// Seconds of game time since the run started (merge timestamps, combos).
  double get clock => _clock;
  double _clock = 0;

  final List<void Function(MergeEvent)> _mergeListeners = [];

  /// Subscribe to completed merges (score, particles, sound, analytics).
  void addMergeListener(void Function(MergeEvent) listener) =>
      _mergeListeners.add(listener);

  void removeMergeListener(void Function(MergeEvent) listener) =>
      _mergeListeners.remove(listener);

  late final DropperComponent dropper;

  /// Creatures currently in the jar (body created and mounted), in the
  /// order they arrived. A creature joins on mount, not at spawn, so
  /// everything in this list always has a physics body.
  final List<CreatureComponent> creatures = [];

  /// Finds touching same-level pairs (see [MergeDetector]).
  final MergeDetector<CreatureComponent> mergeDetector = MergeDetector();

  /// Called for every detected merge pair, after the physics step.
  /// Defaults to [performMerge]; tests may swap it to observe detection.
  late void Function(MergePair<CreatureComponent> pair) onMergeDetected =
      performMerge;

  int _nextId = 0;

  double _cooldown = 0;

  double get pixelsPerUnit => metersToPixels;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad(); // initializes the native Box2D backend
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    dropper = DropperComponent(
      landingFor: landingY,
      reduceMotion: reduceMotion,
    );
    world.touchListener = this;
    addMergeListener(_scoreMerge);
    particles = ParticleSystem(reduceMotion: reduceMotion, seed: _seed);
    world
      ..add(JarWalls())
      ..add(
        DangerLineComponent(danger: () => danger, reduceMotion: reduceMotion),
      )
      ..add(particles)
      ..add(dropper);
    dropper.load(CreatureCatalog.byLevel(_firstLevel));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0) metersToPixels = size.x / GameConstants.worldWidth;
  }

  /// Where a creature of drawn radius [r] dropped straight down at [x]
  /// would first touch something, given where everything is right now.
  /// Drives the aim guide (physics decides the real resting place).
  double landingY(double x, double r) => DropGeometry.landingY(
    x,
    r * PhysicsConfig.collisionScale,
    creatures.map((c) => c.restCircle),
  );

  /// Aim using a pixel X coordinate relative to the GameWidget.
  void aimAtPixel(double px) {
    if (pixelsPerUnit <= 0) return;
    dropper.aim(px / pixelsPerUnit);
  }

  void aimAt(double worldX) => dropper.aim(worldX);

  /// Drops the held creature. Returns false while cooling down.
  bool drop() {
    if (inputLocked || !dropper.isReady) return false;
    final spec = dropper.release()!;
    spawnCreature(
      spec.level,
      // A sub-pixel nudge (±0.02 m) so drops at the exact same x don't
      // build perfectly balanced towers (an unstable equilibrium that only
      // holds because the simulation is exact). Real plush topples.
      Vector2(
        DropGeometry.clampX(
          dropper.x + (_dropJitter.nextDouble() - 0.5) * 0.04,
          spec.radius,
        ),
        GameConstants.holderY,
      ),
      velocity: Vector2(0, PhysicsConfig.dropSpeed),
    );
    drops.value++;
    _cooldown = GameConstants.dropCooldown;
    return true;
  }

  /// Puts a creature of [level] into the jar at [position] (world units).
  /// Used by drops, merges and power-ups.
  CreatureComponent spawnCreature(
    int level,
    Vector2 position, {
    Vector2? velocity,
    bool fromMerge = false,
  }) {
    final id = _nextId++;
    final creature = CreatureComponent(
      id: id,
      spec: CreatureCatalog.byLevel(level),
      position: position,
      velocity: velocity,
      reduceMotion: reduceMotion,
      onMounted: creatures.add,
      onHit: _onCreatureHit,
      onRemoved: _onCreatureRemoved,
      fromMerge: fromMerge,
      seed: _seed * 7919 + id,
    );
    world.add(creature);
    if (level > highestLevel.value) highestLevel.value = level;
    if (_levelsSeen.add(level)) {
      for (final l in List.of(_levelListeners)) {
        l(level);
      }
    }
    return creature;
  }

  void _onCreatureRemoved(CreatureComponent c) {
    creatures.remove(c);
    mergeDetector.forget(c);
  }

  // --- TouchListener (called by JarWorld after each physics step) ---

  @override
  void onTouchBegin(Object a, Object b) {
    if (a is CreatureComponent && b is CreatureComponent) {
      mergeDetector.beginTouch(a, b);
    }
  }

  @override
  void onTouchEnd(Object a, Object b) {
    if (a is CreatureComponent && b is CreatureComponent) {
      mergeDetector.endTouch(a, b);
    }
  }

  /// Merges a detected pair (both creatures are already claimed, so they
  /// can't be in any other merge):
  ///
  /// 1. Remove both creatures.
  /// 2. Spawn the next level at their midpoint (clamped inside the jar),
  ///    carrying part of their momentum, with the pop animation.
  /// 3. For two max-level creatures, spawn nothing and push neighbours
  ///    away with a soft burst instead.
  /// 4. Notify listeners.
  ///
  /// Chain reactions need no extra code: the new creature's contacts start
  /// on the next physics step and go through the detector like any other.
  void performMerge(MergePair<CreatureComponent> pair) {
    final a = pair.a, b = pair.b;
    final pa = a.body.position.clone(), pb = b.body.position.clone();
    final va = a.body.linearVelocity.clone(),
        vb = b.body.linearVelocity.clone();
    final ma = a.body.mass, mb = b.body.mass;
    a.removeFromParent();
    b.removeFromParent();

    final result = pair.resultLevel;
    final Vector2 at;
    int? createdId;
    if (result != null) {
      final r = CreatureCatalog.byLevel(result).radius;
      at = MergeMath.position(pa, pb, r * PhysicsConfig.collisionScale);
      createdId = spawnCreature(
        result,
        at,
        velocity: MergeMath.velocity(va, ma, vb, mb),
        fromMerge: true,
      ).id;
    } else {
      at = (pa + pb)..scale(0.5);
      world.physicsWorld.explode(
        ExplosionDef(
          position: at,
          radius: PhysicsConfig.clearBurstRadius,
          impulsePerLength: PhysicsConfig.clearBurstImpulse,
          falloff: PhysicsConfig.clearBurstFalloff,
        ),
      );
    }

    merges.value++;
    final event = MergeEvent(
      fromLevel: pair.level,
      resultLevel: result,
      position: at,
      time: _clock,
      createdId: createdId,
    );
    for (final l in List.of(_mergeListeners)) {
      l(event);
    }
  }

  void _loadNext() {
    dropper.load(CreatureCatalog.byLevel(spawner.take()));
    nextLevel.value = spawner.peek;
  }

  /// Merge sparkle bursts and shockwave rings (pooled).
  late final ParticleSystem particles;

  /// SWEEP / POP / GROW / SHAKE effects.
  late final PowerUpSystem powerUps = PowerUpSystem(this, seed: _seed);

  /// When true, touches don't aim or drop (e.g. while picking a POP/GROW
  /// target or a dialog is open).
  /// Stops physics, timers and animations but keeps drawing, so overlays
  /// such as a confirm dialog still show the jar's current highlights.
  /// (Flame's pauseEngine also stops rendering.)
  bool frozen = false;

  // ---------------------------------------------------------------------------
  // Game over

  /// Overflow countdown (see [OverflowTimer]).
  final OverflowTimer overflow = OverflowTimer();

  /// Seconds left while the jar is overflowing (3, 2, 1), else null.
  /// Only changes when the number changes.
  final ValueNotifier<int?> overflowCountdown = ValueNotifier(null);

  /// True from the moment the jar overflows (slow-motion included).
  bool get isGameOver => _gameOverAt != null;
  double? _gameOverAt;
  double _slowMoReal = 0;
  bool _gameOverAnnounced = false;

  /// How long the slow-motion ending lasts (real seconds) before listeners
  /// hear about the game over.
  static const double slowMoDuration = 1.3;

  final List<void Function()> _gameOverListeners = [];

  /// Called once, after the slow-motion ending.
  void addGameOverListener(void Function() l) => _gameOverListeners.add(l);

  void _updateOverflow(double dt, {required bool overLine}) {
    if (isGameOver) return;
    if (overflow.update(dt, overLine: overLine)) {
      _gameOverAt = _clock;
      overflowCountdown.value = null;
      inputLocked = true;
      for (final c in creatures) {
        c.react(CreatureExpression.surprised, 99);
      }
      return;
    }
    overflowCountdown.value = overflow.isWarning ? overflow.secondsLeft : null;
  }

  /// How far below the danger line a continue clears (world units; the
  /// jar is 14 tall, so about a quarter of it).
  static const double reviveClearDepth = 3.5;

  /// Keeps a finished run going (rewarded "continue"): clears the creatures
  /// near the top, resets the overflow timer and hands control back.
  /// Returns how many creatures were cleared; 0 (and no change) if the run
  /// isn't over.
  int revive() {
    if (!isGameOver) return 0;
    final cleared = powerUps.clearAbove(
      DangerLineComponent.y + reviveClearDepth,
    );
    overflow.reset();
    overflowCountdown.value = null;
    _gameOverAt = null;
    _slowMoReal = 0;
    _gameOverAnnounced = false;
    frozen = false;
    inputLocked = false;
    for (final c in creatures) {
      c.react(CreatureExpression.happy, 0.8);
    }
    revives++;
    return cleared;
  }

  /// Continues used this run.
  int revives = 0;

  /// Slow-motion factor during the ending: eases from 1 down to 0.15.
  double get _timeScale {
    if (!isGameOver) return 1;
    final t = (_slowMoReal / slowMoDuration).clamp(0.0, 1.0);
    return 1 - 0.85 * (1 - (1 - t) * (1 - t));
  }

  bool get inputLocked => _inputLocked;
  bool _inputLocked = false;
  set inputLocked(bool v) {
    _inputLocked = v;
    // Hide the held creature and aim guide so it's clear drops are off.
    if (isLoaded) dropper.hidden = v;
  }

  /// Creating these creatures for the first time in a run earns a
  /// power-up. Spread out so rewards keep coming as the run deepens.
  static const Map<int, PowerUp> milestoneRewards = {
    6: PowerUp.sweep,
    8: PowerUp.pop,
    10: PowerUp.grow,
    12: PowerUp.shake,
  };

  /// A combo of this size also earns a SHAKE (once per run).
  static const int comboRewardAt = 5;

  final Set<Object> _rewardsGiven = {};
  final List<void Function(PowerUp)> _earnListeners = [];

  final Set<int> _levelsSeen = {};
  final List<void Function(int level)> _levelListeners = [];

  /// Called the first time each creature level appears in this run
  /// (drops, merges, GROW). The UI uses it to unlock Collection entries.
  final List<void Function(ScoreAward award)> _awardListeners = [];

  /// Called after each merge has been scored (combo known), e.g. for
  /// merge sounds and haptics.
  void addScoredMergeListener(void Function(ScoreAward award) l) =>
      _awardListeners.add(l);

  final List<void Function(double speed)> _impactListeners = [];

  /// Creature impacts (approach speed in m/s), e.g. for bounce sounds.
  /// Called from the physics step's event dispatch.
  void addImpactListener(void Function(double speed) l) =>
      _impactListeners.add(l);

  void _onCreatureHit(double speed) {
    for (final l in _impactListeners) {
      l(speed);
    }
  }

  void addLevelReachedListener(void Function(int level) l) =>
      _levelListeners.add(l);

  /// Subscribe to power-ups earned during play (the UI adds them to the
  /// saved inventory).
  void addPowerUpEarnedListener(void Function(PowerUp) l) =>
      _earnListeners.add(l);

  void _checkRewards(MergeEvent e, ScoreAward award) {
    final level = e.resultLevel;
    final byLevel = level == null ? null : milestoneRewards[level];
    if (byLevel != null && _rewardsGiven.add(level!)) _earn(byLevel, e);
    if (award.combo >= comboRewardAt && _rewardsGiven.add('combo')) {
      _earn(PowerUp.shake, e);
    }
  }

  void _earn(PowerUp p, MergeEvent e) {
    for (final l in List.of(_earnListeners)) {
      l(p);
    }
    showPopup(
      '+1 ${p.label}!',
      color: AppColors.candyPurple,
      at: Vector2(size.x / 2, size.y * 0.42),
      scale: 1.05,
      lifetime: 1.5,
    );
  }

  /// 0 = plenty of room … 1 = a settled creature touches the danger line.
  /// Drives worried faces and the pulsing danger line (game over: Phase 10).
  double get danger => _danger;
  double _danger = 0;

  /// [danger] for widgets (the jar's side meter), only notified when it
  /// moves by 2% or more, so the UI doesn't rebuild every frame.
  final ValueNotifier<double> dangerLevel = ValueNotifier(0);

  /// How far below the line (m) the warning starts ramping up.
  static const double dangerZone = 2.4;

  /// Creatures younger than this (just dropped) don't count toward danger.
  static const double _settleGrace = 1.0;

  /// Danger for a jar whose highest settled creature's top edge is at
  /// [highestTop] (world y; smaller = higher). Infinity = empty jar.
  static double dangerFor(double highestTop) {
    if (highestTop == double.infinity) return 0;
    final lineY = DangerLineComponent.y;
    return ((lineY + dangerZone - highestTop) / dangerZone).clamp(0.0, 1.0);
  }

  /// Resting face for everyone at a given danger level.
  static CreatureExpression idleFor(double danger) =>
      danger > 0.55 ? CreatureExpression.worried : CreatureExpression.happy;

  /// Returns whether a settled creature pokes above the danger line.
  bool _updateDanger() {
    var top = double.infinity;
    for (final c in creatures) {
      if (c.isFalling || c.age < _settleGrace || !c.canMerge) continue;
      final t = c.y - c.bodyRadius;
      if (t < top) top = t;
    }
    _danger = dangerFor(top);
    if ((_danger - dangerLevel.value).abs() >= 0.02 ||
        (_danger == 0 && dangerLevel.value != 0)) {
      dangerLevel.value = _danger;
    }
    final idle = idleFor(_danger);
    for (final c in creatures) {
      c.idleExpression = idle;
    }
    return top < DangerLineComponent.y;
  }

  void _mergeEffects(MergeEvent e, ScoreAward award) {
    final big = award.combo >= 4 || e.isMaxClear || e.fromLevel >= 8;
    if (e.isMaxClear) {
      particles.burst(
        e.position,
        count: 48,
        colors: const [
          Color(0xFFFF8FA3),
          Color(0xFFFFD166),
          Color(0xFF8FD3C7),
          Color(0xFF8EC5FF),
          Color(0xFFB8A1FF),
          Color(0xFFFFFFFF),
        ],
        speed: 9,
        size: 0.2,
        life: 1.1,
      );
      particles.ring(e.position, radius: 4, color: AppColors.lavender);
      return;
    }
    final spec = CreatureCatalog.byLevel(e.resultLevel!);
    // 8–15 particles for normal merges, larger bursts for big moments.
    final count = big ? 26 : (8 + e.fromLevel).clamp(8, 15);
    particles.burst(
      e.position,
      count: count,
      colors: [spec.body, spec.light, AppColors.white, AppColors.sunshine],
      speed: 3 + spec.radius * 2.2 + (big ? 2 : 0),
      size: 0.09 + spec.radius * 0.05,
      life: big ? 0.9 : 0.7,
    );
    particles.ring(e.position, radius: spec.radius * 1.9, color: spec.light);

    // Chains make the neighbours wink happily.
    if (award.combo >= 2) {
      for (final c in creatures) {
        if (c.id == e.createdId) continue;
        if (c.body.position.distanceTo(e.position) < 3.2) {
          c.react(CreatureExpression.wink, 0.7);
        }
      }
    }
  }

  void _scoreMerge(MergeEvent e) {
    final award = scoring.onMerge(e);
    _mergeEffects(e, award);
    _checkRewards(e, award);
    for (final l in List.of(_awardListeners)) {
      l(award);
    }
    final big = award.combo >= 4 || e.isMaxClear;
    showPopup(
      award.label,
      sub: '+${award.points}',
      color: _comboColor(award.combo, rainbow: e.isMaxClear),
      // Start just above the new creature so the text never covers it.
      at: worldToScreen(
        e.position -
            Vector2(
              0,
              e.resultLevel == null
                  ? 0
                  : CreatureCatalog.byLevel(e.resultLevel!).radius,
            ),
      ),
      scale: e.isMaxClear ? 1.3 : (big ? 1.15 : 1),
      lifetime: 1.2,
    );
    if (scoring.takeNewBest()) {
      showPopup(
        'NEW BEST!',
        color: AppColors.sunshineDeep,
        at: Vector2(size.x / 2, size.y * 0.28),
        scale: 1.2,
        lifetime: 1.6,
      );
    }
  }

  static Color _comboColor(int combo, {bool rainbow = false}) {
    if (rainbow) return AppColors.lavenderDeep;
    return switch (combo) {
      <= 1 => AppColors.coralDeep,
      2 => AppColors.sunshineDeep,
      3 => AppColors.mintDeep,
      4 => AppColors.skyDeep,
      _ => AppColors.lavenderDeep,
    };
  }

  /// Shows floating text at a screen position (pixels inside the jar),
  /// kept horizontally inside the jar.
  FloatingTextComponent showPopup(
    String label, {
    required Color color,
    required Vector2 at,
    String? sub,
    double scale = 1,
    double lifetime = 1.0,
  }) {
    final fontSize = (size.x * 0.068).clamp(16.0, 40.0) * scale;
    final popup = FloatingTextComponent(
      label: label,
      sub: sub,
      color: color,
      fontSize: fontSize,
      position: at.clone()..y -= fontSize * 0.6,
      reduceMotion: reduceMotion,
      lifetime: lifetime,
    );
    // Rough width estimate for clamping before layout (~0.62 em/char).
    final half = label.length * fontSize * 0.31 + fontSize * 0.2;
    popup.x = popup.x.clamp(half, math.max(half, size.x - half));

    _popups.removeWhere((p) => p.isRemoved || p.isRemoving);
    // Chains fire popups in quick succession at nearly the same spot:
    // older neighbours fade out so the newest one reads cleanly.
    for (final p in _popups) {
      if (p.position.distanceTo(popup.position) < fontSize * 3) {
        p.fadeOutSoon();
      }
    }
    if (_popups.length >= _maxPopups) _popups.removeAt(0).removeFromParent();
    _popups.add(popup);
    camera.viewport.add(popup);
    return popup;
  }

  @override
  void update(double dt) {
    if (frozen) return;
    // Clamp huge frame gaps (app resume, debugger) so nothing teleports.
    final real = dt > 1 / 20 ? 1 / 20 : dt;
    if (isGameOver) {
      _slowMoReal += real;
      if (!_gameOverAnnounced && _slowMoReal >= slowMoDuration) {
        _gameOverAnnounced = true;
        frozen = true;
        for (final l in List.of(_gameOverListeners)) {
          l();
        }
        return;
      }
    }
    final step = reduceMotion ? real : real * _timeScale;
    _clock += step;
    super.update(step);
    // Physics has stepped; now it's safe to act on merges.
    for (final pair in mergeDetector.collect()) {
      onMergeDetected(pair);
    }
    scoring.tick(_clock);
    final overLine = _updateDanger();
    _updateOverflow(step, overLine: overLine);
    if (!dropper.isReady) {
      _cooldown -= dt;
      if (_cooldown <= 0) _loadNext();
    }
  }

  /// Releases the notifiers and the native physics world. Call from the
  /// owning widget's dispose() (after the GameWidget has detached).
  void disposeSession() {
    nextLevel.dispose();
    drops.dispose();
    merges.dispose();
    highestLevel.dispose();
    dangerLevel.dispose();
    overflowCountdown.dispose();
    _gameOverListeners.clear();
    _mergeListeners.clear();
    scoring.dispose();
    powerUps.dispose();
    _earnListeners.clear();
    _levelListeners.clear();
    _awardListeners.clear();
    _impactListeners.clear();
    mergeDetector.clear();
    if (isLoaded) world.disposePhysics();
  }
}
