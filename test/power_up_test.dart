import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/repositories/save_controller.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:fluffy_merge/game/physics/physics_config.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

double _r(int l) =>
    CreatureCatalog.byLevel(l).radius * PhysicsConfig.collisionScale;
double _floorY(int l) => GameConstants.worldHeight - _r(l);

Future<void> _settle(FluffyGame game, double seconds) async {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    game.update(1 / 60);
    await game.ready();
  }
}

void main() {
  group('Power-up stock (save controller)', () {
    Future<ProviderContainer> container([
      Map<String, Object> saved = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(saved);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('new players start with 3 of each', () async {
      final c = await container();
      expect(c.read(powerUpCountsProvider), {
        for (final p in PowerUp.values) p: SaveData.starterPowerUps,
      });
    });

    test('consume spends one, persists, and never goes below 0', () async {
      final c = await container({SaveKeys.powerUp(PowerUp.pop): 1});
      final save = c.read(saveProvider.notifier);
      expect(save.consumePowerUp(PowerUp.pop), isTrue);
      expect(save.consumePowerUp(PowerUp.pop), isFalse);
      expect(c.read(powerUpCountsProvider)[PowerUp.pop], 0);
      await save.flush();
      expect(
        readSave(c.read(sharedPreferencesProvider)).powerUpCount(PowerUp.pop),
        0,
      );
    });

    test('add is capped', () async {
      final c = await container({SaveKeys.powerUp(PowerUp.grow): 98});
      c.read(saveProvider.notifier).addPowerUp(PowerUp.grow, 5);
      expect(c.read(powerUpCountsProvider)[PowerUp.grow], SaveData.maxPowerUps);
    });
  });

  group('Power-up effects in the jar', () {
    void physicsTest(String name, Future<void> Function(FluffyGame g) body) {
      testWithGame<FluffyGame>(name, () => FluffyGame(seed: 2), (game) async {
        try {
          await game.ready();
          await body(game);
        } finally {
          game.disposeSession();
        }
      });
    }

    physicsTest('SWEEP targets levels 1–2, else the lowest level present', (
      game,
    ) async {
      game
        ..spawnCreature(1, Vector2(1, _floorY(1)))
        ..spawnCreature(2, Vector2(3.5, _floorY(2)))
        ..spawnCreature(5, Vector2(7, _floorY(5)));
      await game.ready();
      expect(game.powerUps.sweepTargets().map((c) => c.level).toSet(), {1, 2});
      expect(game.powerUps.sweep(), 2);
      await _settle(game, 0.2);
      expect(game.creatures.map((c) => c.level), [5]);
      // Nothing small left → the lowest level present.
      expect(game.powerUps.sweepTargets().single.level, 5);
    });

    physicsTest('POP removes exactly the chosen creature', (game) async {
      final a = game.spawnCreature(3, Vector2(2, _floorY(3)));
      final b = game.spawnCreature(4, Vector2(7, _floorY(4)));
      await game.ready();
      expect(game.powerUps.pop(b), isTrue);
      expect(game.powerUps.pop(b), isFalse, reason: 'already gone');
      await _settle(game, 0.2);
      expect(game.creatures, [a]);
      expect(game.particles.activeCount, greaterThan(0));
    });

    physicsTest('GROW upgrades in place; max level cannot grow', (game) async {
      final c = game.spawnCreature(3, Vector2(5, _floorY(3)));
      final top = game.spawnCreature(12, Vector2(1.5, _floorY(12)));
      await game.ready();
      expect(game.powerUps.canTarget(PowerUp.grow, top), isFalse);
      expect(game.powerUps.grow(c), isTrue);
      await _settle(game, 0.3);
      final grown = game.creatures.firstWhere((x) => x.id != top.id);
      expect(grown.level, 4);
      expect(grown.x, closeTo(5, 0.3));
    });

    physicsTest('GROW into a match triggers a merge', (game) async {
      final rr = _r(4);
      game.spawnCreature(4, Vector2(4, _floorY(4)));
      final small = game.spawnCreature(
        3,
        Vector2(4 + rr + _r(3) + 0.01, _floorY(3)),
      );
      await game.ready();
      await _settle(game, 0.5);
      expect(game.merges.value, 0);
      game.powerUps.grow(small);
      await _settle(game, 1.5);
      expect(game.merges.value, 1);
      expect(game.creatures.single.level, 5);
    });

    physicsTest('SHAKE tosses creatures upward and wobbles the jar', (
      game,
    ) async {
      for (var i = 0; i < 4; i++) {
        game.spawnCreature(i + 1, Vector2(1.5 + i * 2.2, _floorY(i + 1)));
      }
      await game.ready();
      await _settle(game, 2);
      final before = {for (final c in game.creatures) c.id: c.y};
      game.powerUps.shake();
      expect(game.powerUps.shakes.value, 1);
      await _settle(game, 0.15);
      for (final c in game.creatures) {
        expect(c.y, lessThan(before[c.id]!), reason: 'L${c.level} lifted');
      }
      await _settle(game, 3);
      for (final c in game.creatures) {
        expect(
          c.x,
          inInclusiveRange(c.bodyRadius - 0.03, 10 - c.bodyRadius + 0.03),
        );
      }
    });

    physicsTest('picking: hit test by pixel, highlights, input lock', (
      game,
    ) async {
      game.onGameResize(Vector2(400, 560));
      final c = game.spawnCreature(5, Vector2(5, _floorY(5)));
      await game.ready();
      final px = game.worldToScreen(c.body.position);
      expect(game.powerUps.creatureAtPixel(px), c);
      expect(game.powerUps.creatureAtPixel(Vector2(5, 5)), isNull);

      game.powerUps.highlight((x) => x.level == 5);
      expect(c.highlighted, isTrue);
      game.powerUps.highlight(null);
      expect(c.highlighted, isFalse);

      game.inputLocked = true;
      await _settle(game, GameConstants.dropCooldown + 0.1);
      expect(game.drop(), isFalse, reason: 'no drops while picking');
    });

    physicsTest('earning: first Lv. 6 of the run grants one SWEEP', (
      game,
    ) async {
      final earned = <PowerUp>[];
      game.addPowerUpEarnedListener(earned.add);
      Future<void> mergeTwoFives(double x) async {
        final r5 = _r(5);
        game
          ..spawnCreature(5, Vector2(x, _floorY(5)))
          ..spawnCreature(5, Vector2(x + 2 * r5 + 0.001, _floorY(5)));
        await game.ready();
        await _settle(game, 1);
      }

      await mergeTwoFives(1.2);
      expect(earned, [PowerUp.sweep]);
      game.powerUps.pop(game.creatures.single);
      await _settle(game, 0.3);
      await mergeTwoFives(1.2);
      expect(earned, [PowerUp.sweep], reason: 'once per run');
    });
  });
}
