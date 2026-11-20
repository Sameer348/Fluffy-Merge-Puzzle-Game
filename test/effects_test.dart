import 'dart:ui';

import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/components/particle_system.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/physics/physics_config.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

const _colors = [Color(0xFFFF8FA3), Color(0xFFFFFFFF)];

void main() {
  group('ParticleSystem pool', () {
    test('burst adds particles; they expire and free their slots', () {
      final p = ParticleSystem(seed: 1);
      p.burst(Vector2(5, 5), count: 12, colors: _colors, life: 0.5);
      expect(p.activeCount, 12);
      for (var i = 0; i < 18; i++) {
        p.update(1 / 60);
      }
      // Lifetimes vary 0.35–0.65 s, so all are alive at 0.3 s…
      expect(p.activeCount, 12);
      for (var i = 0; i < 24; i++) {
        p.update(1 / 60);
      }
      // …and all gone by 0.7 s.
      expect(p.activeCount, 0);
    });

    test('never exceeds capacity: oldest particles are recycled', () {
      final p = ParticleSystem(capacity: 50, seed: 1);
      for (var i = 0; i < 10; i++) {
        p.burst(Vector2(5, 5), count: 15, colors: _colors);
      }
      expect(p.activeCount, 50);
    });

    test('rings are pooled and expire', () {
      final p = ParticleSystem(ringCapacity: 3, seed: 1);
      for (var i = 0; i < 5; i++) {
        p.ring(Vector2(1, 1), radius: 2, color: _colors.first);
      }
      expect(p.activeRings, 3);
      for (var i = 0; i < 40; i++) {
        p.update(1 / 60);
      }
      expect(p.activeRings, 0);
    });

    test('reduced motion: a third of the particles and no rings', () {
      final p = ParticleSystem(reduceMotion: true, seed: 1);
      p.burst(Vector2(5, 5), count: 15, colors: _colors);
      p.ring(Vector2(5, 5), radius: 2, color: _colors.first);
      expect(p.activeCount, 5);
      expect(p.activeRings, 0);
    });

    test('renders every shape without error', () {
      final p = ParticleSystem(seed: 3);
      p.burst(Vector2(5, 5), count: 60, colors: _colors);
      p.ring(Vector2(5, 5), radius: 2, color: _colors.first);
      p.update(0.1);
      final rec = PictureRecorder();
      p.render(Canvas(rec));
      rec.endRecording().dispose();
    });
  });

  group('Danger rules', () {
    final line = GameConstants.worldHeight * GameConstants.dangerLineFraction;
    test('0 when empty or well below the zone', () {
      expect(FluffyGame.dangerFor(double.infinity), 0);
      expect(FluffyGame.dangerFor(line + FluffyGame.dangerZone + 1), 0);
    });
    test('ramps to 1 as the pile reaches the line', () {
      expect(
        FluffyGame.dangerFor(line + FluffyGame.dangerZone / 2),
        closeTo(0.5, 1e-9),
      );
      expect(FluffyGame.dangerFor(line), 1);
      expect(FluffyGame.dangerFor(line - 3), 1, reason: 'clamped');
    });
    test('worried above 0.55', () {
      expect(FluffyGame.idleFor(0.5), CreatureExpression.happy);
      expect(FluffyGame.idleFor(0.6), CreatureExpression.worried);
    });
  });

  group('In the jar', () {
    double floorY(int l) =>
        GameConstants.worldHeight -
        CreatureCatalog.byLevel(l).radius * PhysicsConfig.collisionScale;

    Future<void> settle(FluffyGame game, double seconds) async {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        game.update(1 / 60);
        await game.ready();
      }
    }

    testWithGame<FluffyGame>(
      'a merge fires a burst and a ring',
      () => FluffyGame(seed: 1),
      (game) async {
        try {
          await game.ready();
          final r = CreatureCatalog.byLevel(3).radius * 0.95;
          game
            ..spawnCreature(3, Vector2(4, floorY(3)))
            ..spawnCreature(3, Vector2(4 + 2 * r + 0.001, floorY(3)));
          await game.ready();
          for (var i = 0; i < 60 && game.merges.value == 0; i++) {
            await settle(game, 1 / 60);
          }
          expect(game.merges.value, 1);
          expect(game.particles.activeCount, inInclusiveRange(8, 15));
          expect(game.particles.activeRings, 1);
          await settle(game, 1.5);
          expect(game.particles.activeCount, 0);
        } finally {
          game.disposeSession();
        }
      },
    );

    testWithGame<FluffyGame>(
      'calm jar: no danger, happy faces',
      () => FluffyGame(seed: 1),
      (game) async {
        try {
          await game.ready();
          final low = game.spawnCreature(5, Vector2(2, floorY(5)));
          // Spawned at rest (no impact): counts as landed after 1.5 s.
          await settle(game, 2);
          expect(game.danger, 0);
          expect(low.expression, CreatureExpression.happy);
        } finally {
          game.disposeSession();
        }
      },
    );
  });
}
