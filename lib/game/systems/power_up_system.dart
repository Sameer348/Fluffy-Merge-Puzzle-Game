import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../components/creature_component.dart';
import '../fluffy_game.dart';
import '../models/creature_spec.dart';
import '../models/power_up.dart';

/// Applies power-up effects inside the jar. The UI owns the flow (pick a
/// target, confirm, spend inventory); this class only changes the world.
///
/// Every effect runs between physics steps (from UI callbacks), never
/// during one, so adding/removing bodies is safe.
class PowerUpSystem {
  PowerUpSystem(this.game, {int seed = 0}) : _rng = math.Random(seed ^ 0xB00);

  final FluffyGame game;
  final math.Random _rng;

  /// Bumps when SHAKE fires; the jar widget listens to wobble itself.
  final ValueNotifier<int> shakes = ValueNotifier(0);

  /// SWEEP clears creatures at or below this level…
  static const int sweepMaxLevel = 2;

  bool _mergeable(CreatureComponent c) => c.canMerge;

  // ---------------------------------------------------------------------------
  // Targeting

  /// Whether [p] can be used on [c] (POP: anything; GROW: below max level).
  bool canTarget(PowerUp p, CreatureComponent c) => switch (p) {
    PowerUp.pop => _mergeable(c),
    PowerUp.grow => _mergeable(c) && c.level < GameConstants.maxLevel,
    _ => false,
  };

  /// The creature under a pixel position inside the GameWidget, if any.
  /// Generous touch slop so small puffs are easy to hit with a finger.
  CreatureComponent? creatureAtPixel(Vector2 px, {PowerUp? forPowerUp}) {
    if (game.pixelsPerUnit <= 0) return null;
    final p = px / game.pixelsPerUnit;
    const slop = 0.25;
    CreatureComponent? best;
    var bestD = double.infinity;
    for (final c in game.creatures) {
      if (forPowerUp != null && !canTarget(forPowerUp, c)) continue;
      final d = c.body.position.distanceTo(p) - c.bodyRadius;
      if (d < slop && d < bestD) {
        best = c;
        bestD = d;
      }
    }
    return best;
  }

  /// Glow the creatures that [test] accepts (null clears all highlights).
  void highlight(bool Function(CreatureComponent c)? test) {
    for (final c in game.creatures) {
      c.highlighted = test != null && test(c);
    }
  }

  // ---------------------------------------------------------------------------
  // Effects

  /// Creatures SWEEP would clear: everything at level ≤ [sweepMaxLevel],
  /// or, if there are none, every creature of the lowest level present.
  List<CreatureComponent> sweepTargets() {
    final pool = game.creatures.where(_mergeable).toList();
    if (pool.isEmpty) return const [];
    final small = pool.where((c) => c.level <= sweepMaxLevel).toList();
    if (small.isNotEmpty) return small;
    final lowest = pool.map((c) => c.level).reduce(math.min);
    return pool.where((c) => c.level == lowest).toList();
  }

  /// Removes [sweepTargets] with a little puff each. Returns how many.
  int sweep() {
    final targets = sweepTargets();
    for (final c in targets) {
      _poof(c, small: true);
    }
    return targets.length;
  }

  /// Removes one creature. False if it can't be targeted any more (e.g. it
  /// merged while the confirm dialog was open).
  bool pop(CreatureComponent c) {
    if (!canTarget(PowerUp.pop, c)) return false;
    _poof(c, small: false);
    return true;
  }

  /// Replaces a creature with the next level in place (with the merge
  /// pop). Normal merge detection then picks up any new matches.
  bool grow(CreatureComponent c) {
    if (!canTarget(PowerUp.grow, c)) return false;
    final at = c.body.position.clone();
    final v = c.body.linearVelocity.clone();
    c
      ..claimedForMerge = true
      ..removeFromParent();
    final next = game.spawnCreature(
      c.level + 1,
      at,
      velocity: v,
      fromMerge: true,
    );
    final spec = next.spec;
    game.particles
      ..burst(
        at,
        count: 14,
        colors: [
          spec.body,
          spec.light,
          AppColors.candyGreenTop,
          AppColors.white,
        ],
        speed: 3.5,
        size: 0.11,
      )
      ..ring(at, radius: spec.radius * 2, color: AppColors.candyGreenTop);
    return true;
  }

  /// Gently tosses every creature upward and away from the pile's centre,
  /// loosening jams. Impulses scale with mass so big and small puffs move
  /// alike, and stay well under the physics speed cap.
  void shake() {
    final cs = game.creatures.where((c) => c.isMounted).toList();
    if (cs.isEmpty) {
      shakes.value++;
      return;
    }
    var cx = 0.0;
    for (final c in cs) {
      cx += c.x;
    }
    cx /= cs.length;
    for (final c in cs) {
      final side = (c.x - cx).sign;
      final vx =
          side * (1.2 + _rng.nextDouble() * 1.6) +
          (_rng.nextDouble() - 0.5) * 1.5;
      final vy = -(3.5 + _rng.nextDouble() * 3.0);
      final m = c.body.mass;
      c.body.applyLinearImpulse(Vector2(vx * m, vy * m));
      c.body.angularVelocity += (_rng.nextDouble() - 0.5) * 6;
      c.react(CreatureExpression.surprised, 0.6);
    }
    shakes.value++;
  }

  void _poof(CreatureComponent c, {required bool small}) {
    final at = c.body.position.clone();
    final spec = c.spec;
    c
      ..claimedForMerge = true
      ..removeFromParent();
    game.particles.burst(
      at,
      count: small ? 8 : 16,
      colors: [spec.body, spec.light, AppColors.white],
      speed: small ? 2.5 : 4.5,
      size: 0.08 + spec.radius * 0.05,
      life: 0.6,
    );
    if (!small) {
      game.particles.ring(at, radius: spec.radius * 1.8, color: spec.light);
    }
  }

  void dispose() => shakes.dispose();
}
