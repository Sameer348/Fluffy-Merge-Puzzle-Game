import 'dart:math' as math;

import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/physics/jar_walls.dart';
import 'package:fluffy_merge/game/systems/drop_geometry.dart';
import 'package:fluffy_merge/game/systems/spawn_queue.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances the game in 1/60 s steps (like real frames).
/// Advances in 1/60 s frames, letting async component loads (new bodies)
/// complete between frames like a real app does.
Future<void> _run(FluffyGame game, double seconds) async {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    game.update(1 / 60);
    await game.ready();
  }
}

void main() {
  const floor = GameConstants.worldHeight;

  group('SpawnQueue', () {
    test('first creature is always level 1, peek matches take', () {
      final q = SpawnQueue(seed: 42);
      expect(q.take(), 1);
      for (var i = 0; i < 50; i++) {
        final p = q.peek;
        expect(q.take(), p);
      }
    });

    test('same seed → same sequence; only levels 1..5', () {
      final a = SpawnQueue(seed: 7), b = SpawnQueue(seed: 7);
      final seqA = [for (var i = 0; i < 200; i++) a.take()];
      final seqB = [for (var i = 0; i < 200; i++) b.take()];
      expect(seqA, seqB);
      expect(
        seqA.every((l) => l >= 1 && l <= GameConstants.maxSpawnLevel),
        isTrue,
      );
    });

    test('distribution favours small creatures', () {
      final q = SpawnQueue(seed: 1);
      final counts = List.filled(6, 0);
      for (var i = 0; i < 20000; i++) {
        counts[q.take()]++;
      }
      for (var l = 1; l < 5; l++) {
        expect(counts[l], greaterThan(counts[l + 1]), reason: 'level $l');
      }
    });
  });

  group('DropGeometry', () {
    test('lands on the floor when the column is empty', () {
      expect(DropGeometry.landingY(5, 0.5, const []), floor - 0.5);
    });

    test('stacks exactly on top of a circle directly below', () {
      final below = (x: 5.0, y: floor - 1.0, r: 1.0);
      expect(
        DropGeometry.landingY(5, 0.5, [below]),
        closeTo(below.y - 1.5, 1e-9),
      );
    });

    test(
      'off-center contact rests on the shoulder (touching, not overlapping)',
      () {
        final below = (x: 5.0, y: floor - 1.0, r: 1.0);
        final y = DropGeometry.landingY(5.8, 0.5, [below]);
        final dist = (Vector2(5.8, y) - Vector2(5, below.y)).length;
        expect(dist, closeTo(1.5, 1e-5));
      },
    );

    test('ignores circles that are not under the drop column', () {
      final away = (x: 1.0, y: floor - 1.0, r: 1.0);
      expect(DropGeometry.landingY(8, 0.5, [away]), floor - 0.5);
    });

    test('clampX keeps creatures inside the walls', () {
      expect(DropGeometry.clampX(-3, 0.7), 0.7);
      expect(DropGeometry.clampX(99, 0.7), GameConstants.worldWidth - 0.7);
      expect(DropGeometry.clampX(4, 0.7), 4);
    });
  });

  group('Jar walls', () {
    test('every collidable wall segment faces into the jar', () {
      final pts = JarWalls.chainPoints();
      final center = Vector2(
        GameConstants.worldWidth / 2,
        GameConstants.worldHeight / 2,
      );
      // Skip the ghost segments at both ends.
      for (var i = 1; i < pts.length - 2; i++) {
        final a = pts[i], b = pts[i + 1];
        final d = b - a;
        final normal = Vector2(d.y, -d.x); // Box2D right-perp
        final toCenter = center - (a + b) / 2;
        expect(normal.dot(toCenter), greaterThan(0), reason: 'segment $i');
      }
    });
  });

  group('FluffyGame physics', () {
    // Each test frees its native Box2D world.
    void physicsTest(
      String name,
      int seed,
      Future<void> Function(FluffyGame game) body,
    ) {
      testWithGame<FluffyGame>(name, () => FluffyGame(seed: seed), (
        game,
      ) async {
        try {
          await game.ready();
          await body(game);
        } finally {
          game.disposeSession();
        }
      });
    }

    Future<void> dropAt(FluffyGame game, double x) async {
      await _run(game, GameConstants.dropCooldown + 0.05);
      game.aimAt(x);
      expect(game.drop(), isTrue);
      await game.ready(); // creates the body
    }

    physicsTest('camera maps jar width to 10 meters', 3, (game) async {
      game.onGameResize(Vector2(300, 420));
      expect(game.pixelsPerUnit, closeTo(30, 1e-9));
      game.aimAtPixel(150);
      await _run(game, 0.5);
      expect(game.dropper.x, closeTo(5, 0.01));
    });

    physicsTest('fixed step: 1 s of 60 Hz frames = 120 physics steps', 3, (
      game,
    ) async {
      final before = game.world.stepCount;
      await _run(game, 1);
      expect(game.world.stepCount - before, inInclusiveRange(119, 121));
    });

    physicsTest('drop falls, lands on the floor, then sleeps', 3, (game) async {
      await dropAt(game, 5);
      expect(game.drop(), isFalse, reason: 'cooldown blocks double drops');
      final c = game.creatures.single;
      expect(c.isFalling, isTrue);
      expect(c.expression, CreatureExpression.surprised);

      await _run(game, 1.2);
      expect(c.isFalling, isFalse);
      expect(c.y, closeTo(floor - c.bodyRadius, 0.03));
      expect(c.x, closeTo(5, 0.05));

      await _run(game, 4);
      expect(c.isSleeping, isTrue, reason: 'resting bodies go to sleep');
      expect(c.expression, CreatureExpression.happy);
    });

    physicsTest('quick tap drops exactly at the finger', 3, (game) async {
      game.aimAt(1.0); // finger down + up in the same frame
      expect(game.drop(), isTrue);
      await game.ready();
      // Within the ±0.02 m anti-tower nudge.
      expect(game.creatures.single.x, closeTo(1.0, 0.021));
    });

    physicsTest(
      '40 drops (with merges): nothing tunnels, escapes or overlaps',
      5,
      (game) async {
        const xs = [1.0, 9.0, 5.0, 3.0, 7.0, 2.0, 8.0, 4.5, 5.5, 0.3];
        for (var i = 0; i < 40; i++) {
          await dropAt(game, xs[i % xs.length]);
        }
        await _run(game, 6);

        final cs = game.creatures;
        // Merges remove two creatures and add one (no Rainbow clears in
        // a run this short).
        expect(cs, hasLength(40 - game.merges.value));
        expect(game.merges.value, greaterThan(0));
        for (final c in cs) {
          expect(
            c.x,
            inInclusiveRange(
              c.bodyRadius - 0.03,
              GameConstants.worldWidth - c.bodyRadius + 0.03,
            ),
          );
          expect(c.y, lessThanOrEqualTo(floor - c.bodyRadius + 0.03));
        }
        for (var i = 0; i < cs.length; i++) {
          for (var j = i + 1; j < cs.length; j++) {
            final d = math.sqrt(
              math.pow(cs[i].x - cs[j].x, 2) + math.pow(cs[i].y - cs[j].y, 2),
            );
            // Box2D allows ~0.005 m linear slop; anything deeper is tunneling.
            expect(
              d,
              greaterThan(cs[i].bodyRadius + cs[j].bodyRadius - 0.05),
              reason: 'creatures $i and $j overlap',
            );
          }
        }
      },
    );

    test(
      'deterministic: same seed + same inputs → identical positions',
      () async {
        Future<List<double>> simulate() async {
          final game = await initializeGame(() => FluffyGame(seed: 9));
          try {
            for (final x in [2.0, 2.4, 6.0, 5.1, 7.7, 3.3]) {
              await _run(game, GameConstants.dropCooldown + 0.05);
              game.aimAt(x);
              game.drop();
              await game.ready();
            }
            await _run(game, 3);
            return [
              for (final c in game.creatures) ...[c.x, c.y],
            ];
          } finally {
            game.disposeSession();
            game.onRemove();
          }
        }

        final a = await simulate();
        final b = await simulate();
        expect(a, b);
      },
    );

    physicsTest('NEXT notifier follows the spawn queue', 11, (game) async {
      final expectedNext = game.spawner.peek;
      expect(game.nextLevel.value, expectedNext);
      game.drop();
      await _run(game, GameConstants.dropCooldown + 0.1);
      expect(game.dropper.held!.level, expectedNext);
      expect(game.nextLevel.value, game.spawner.peek);
    });
  });
}
