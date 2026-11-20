import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/components/creature_component.dart';
import 'package:fluffy_merge/game/components/floating_text_component.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/models/merge_event.dart';
import 'package:fluffy_merge/game/physics/physics_config.dart';
import 'package:fluffy_merge/game/systems/merge_math.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

double _r(int level) =>
    CreatureCatalog.byLevel(level).radius * PhysicsConfig.collisionScale;

double _floorY(int level) => GameConstants.worldHeight - _r(level);

void main() {
  group('MergeMath', () {
    test('midpoint of the pair', () {
      final p = MergeMath.position(Vector2(2, 10), Vector2(4, 12), 0.5);
      expect(p, Vector2(3, 11));
    });

    test('result is pushed inside the walls and above the floor', () {
      final left = MergeMath.position(Vector2(0.5, 13), Vector2(0.9, 13), 1.2);
      expect(left.x, closeTo(1.2, 1e-5));
      expect(left.y, closeTo(GameConstants.worldHeight - 1.2, 1e-5));
      final right = MergeMath.position(Vector2(9.6, 5), Vector2(9.4, 5), 1);
      expect(right.x, closeTo(GameConstants.worldWidth - 1, 1e-5));
    });

    test('velocity is the softened momentum average', () {
      final v = MergeMath.velocity(Vector2(2, 0), 1, Vector2(0, 4), 3);
      // (2*1 + 0*3)/4 = 0.5, (0 + 12)/4 = 3 → × 0.6
      expect(v.x, closeTo(0.3, 1e-5));
      expect(v.y, closeTo(1.8, 1e-5));
      expect(
        MergeMath.velocity(Vector2(1, 1), 0, Vector2(1, 1), 0),
        Vector2.zero(),
      );
    });
  });

  test('merge pop keyframes 1.0 → 1.25 → 0.85 → 1.0', () {
    expect(CreatureComponent.popScale(0), 1);
    expect(CreatureComponent.popScale(0.3), closeTo(1.25, 1e-9));
    expect(CreatureComponent.popScale(0.65), closeTo(0.85, 1e-9));
    expect(CreatureComponent.popScale(1), 1);
    // Continuous (no visible jumps).
    for (var t = 0.0; t < 1; t += 0.01) {
      expect(
        (CreatureComponent.popScale(t + 0.01) - CreatureComponent.popScale(t))
            .abs(),
        lessThan(0.05),
      );
    }
  });

  group('Merging in the jar', () {
    void physicsTest(
      String name,
      Future<void> Function(FluffyGame game, List<MergeEvent> events) body,
    ) {
      testWithGame<FluffyGame>(name, () => FluffyGame(seed: 1), (game) async {
        final events = <MergeEvent>[];
        try {
          await game.ready();
          game.addMergeListener(events.add);
          await body(game, events);
        } finally {
          game.disposeSession();
        }
      });
    }

    /// Runs frame by frame, letting async component loads finish.
    Future<void> settle(FluffyGame game, double seconds) async {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        game.update(1 / 60);
        await game.ready();
      }
    }

    physicsTest('two Berry Puffs become one Lemon Puff at their midpoint', (
      game,
      events,
    ) async {
      game.spawnCreature(2, Vector2(5, _floorY(2)));
      game.spawnCreature(2, Vector2(5.05, 9));
      await game.ready();
      // Step until the merge, then check its popup while it's alive.
      for (var i = 0; i < 90 && game.merges.value == 0; i++) {
        await settle(game, 1 / 60);
      }
      expect(game.merges.value, 1);
      final popups = game.camera.viewport.children
          .whereType<FloatingTextComponent>()
          .toList();
      expect(popups.single.label, 'MERGE!');
      expect(popups.single.sub, '+30');
      await settle(game, 1.4);
      expect(
        game.camera.viewport.children.whereType<FloatingTextComponent>(),
        isEmpty,
        reason: 'popups clean themselves up',
      );

      expect(events, hasLength(1));
      final e = events.single;
      expect(e.fromLevel, 2);
      expect(e.resultLevel, 3);
      expect(e.isMaxClear, isFalse);
      expect(game.merges.value, 1);
      expect(game.highestLevel.value, 3);

      final c = game.creatures.single;
      expect(c.level, 3);
      expect(c.id, e.createdId);
      expect(c.fromMerge, isTrue);
      expect(c.isFalling, isFalse, reason: 'merged creatures start landed');
      expect(e.position.x, closeTo(5, 0.2));

      expect(game.scoring.score.value, 30);
    });

    physicsTest('chain reaction: L1+L1 → L2, which meets an L2 → L3', (
      game,
      events,
    ) async {
      final r1 = _r(1), r2 = _r(2);
      const ax = 3.0;
      final mid = ax + r1;
      // Existing L2 placed so the merged L2 lands touching it.
      game.spawnCreature(2, Vector2(mid + 2 * r2 - 0.01, _floorY(2)));
      game.spawnCreature(1, Vector2(ax, _floorY(1)));
      game.spawnCreature(1, Vector2(ax + 2 * r1 + 0.001, _floorY(1)));
      await game.ready();
      await settle(game, 2);

      expect(events.map((e) => (e.fromLevel, e.resultLevel)), [(1, 2), (2, 3)]);
      expect(game.creatures.map((c) => c.level), [3]);
      // Chain → combo: 10 (×1) then 30 (×2).
      expect(game.scoring.score.value, 10 + 60);
      expect(game.scoring.bestCombo, 2);
      expect(
        events[1].time - events[0].time,
        lessThan(0.5),
        reason: 'chain follows quickly',
      );
    });

    physicsTest('three touching Tiny Puffs: one merge, one left over', (
      game,
      events,
    ) async {
      final r = _r(1);
      for (var i = 0; i < 3; i++) {
        game.spawnCreature(1, Vector2(3 + i * (2 * r + 0.001), _floorY(1)));
      }
      await game.ready();
      await settle(game, 1.5);
      expect(events, hasLength(1));
      expect(game.creatures.map((c) => c.level).toList()..sort(), [1, 2]);
    });

    physicsTest('two Rainbow Puffs: both vanish in a burst', (
      game,
      events,
    ) async {
      const top = GameConstants.maxLevel;
      final r = _r(top);
      game.spawnCreature(top, Vector2(5 - r - 0.001, _floorY(top)));
      game.spawnCreature(top, Vector2(5 + r + 0.001, _floorY(top)));
      final bystander = game.spawnCreature(1, Vector2(0.6, _floorY(1)));
      await game.ready();
      await settle(game, 0.5);

      expect(events, hasLength(1));
      expect(events.single.isMaxClear, isTrue);
      expect(events.single.createdId, isNull);
      expect(game.creatures, [bystander]);

      await settle(game, 2);
      expect(bystander.x, inInclusiveRange(_r(1) - 0.03, 10 - _r(1) + 0.03));
      expect(bystander.y, lessThanOrEqualTo(_floorY(1) + 0.03));
    });

    physicsTest('listeners can unsubscribe', (game, events) async {
      final other = <MergeEvent>[];
      game
        ..addMergeListener(other.add)
        ..removeMergeListener(other.add);
      final r = _r(1);
      game
        ..spawnCreature(1, Vector2(4, _floorY(1)))
        ..spawnCreature(1, Vector2(4 + 2 * r + 0.001, _floorY(1)));
      await game.ready();
      await settle(game, 0.5);
      expect(events, hasLength(1));
      expect(other, isEmpty);
    });
  });
}
