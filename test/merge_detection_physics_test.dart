import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/components/creature_component.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/systems/merge_detector.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances in 1/60 s frames, letting async component loads (new bodies)
/// complete between frames like a real app does.
Future<void> _run(FluffyGame game, double seconds) async {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    game.update(1 / 60);
    await game.ready();
  }
}

/// Merge detection driven by real Box2D contacts.
void main() {
  const floor = GameConstants.worldHeight;

  void physicsTest(
    String name,
    Future<void> Function(
      FluffyGame game,
      List<MergePair<CreatureComponent>> detected,
    )
    body,
  ) {
    testWithGame<FluffyGame>(name, () => FluffyGame(seed: 1), (game) async {
      final detected = <MergePair<CreatureComponent>>[];
      // Record only: claims stay set, like a real merge would remove them.
      game.onMergeDetected = detected.add;
      try {
        await game.ready();
        await body(game, detected);
      } finally {
        game.disposeSession();
      }
    });
  }

  Future<CreatureComponent> spawn(
    FluffyGame game,
    int level,
    double x,
    double y,
  ) async {
    final c = game.spawnCreature(level, Vector2(x, y));
    await game.ready();
    return c;
  }

  double floorY(int level) =>
      floor - CreatureCatalog.byLevel(level).radius * 0.95;

  physicsTest('two same-level creatures landing on each other → one pair', (
    game,
    detected,
  ) async {
    final a = await spawn(game, 2, 5, floorY(2));
    final b = await spawn(game, 2, 5.05, 9);
    await _run(game, 1.5);
    expect(detected, hasLength(1));
    expect({detected.single.a, detected.single.b}, {a, b});
    expect(detected.single.resultLevel, 3);
  });

  physicsTest('side-by-side on the floor (no fall) is detected too', (
    game,
    detected,
  ) async {
    final r = CreatureCatalog.byLevel(1).radius * 0.95;
    await spawn(game, 1, 4, floorY(1));
    await spawn(game, 1, 4 + 2 * r + 0.002, floorY(1));
    await _run(game, 0.3);
    expect(detected, hasLength(1));
  });

  physicsTest('different levels touching → nothing', (game, detected) async {
    await spawn(game, 1, 5, floorY(1));
    await spawn(game, 2, 5, 8);
    await _run(game, 2);
    expect(detected, isEmpty);
    expect(game.mergeDetector.touchingPairCount, greaterThan(0));
  });

  physicsTest('same level but apart → nothing', (game, detected) async {
    await spawn(game, 3, 2, floorY(3));
    await spawn(game, 3, 8, floorY(3));
    await _run(game, 1);
    expect(detected, isEmpty);
  });

  physicsTest('pile of four level-1 creatures: no creature merges twice', (
    game,
    detected,
  ) async {
    await spawn(game, 1, 5, floorY(1));
    await spawn(game, 1, 4.4, 10);
    await spawn(game, 1, 5.6, 8);
    await spawn(game, 1, 5, 6);
    await _run(game, 3);
    expect(detected, isNotEmpty);
    final ids = [
      for (final p in detected) ...[p.a.id, p.b.id],
    ];
    expect(ids.toSet(), hasLength(ids.length), reason: '$detected');
  });

  physicsTest('removing a creature drops it from tracking', (
    game,
    detected,
  ) async {
    final a = await spawn(game, 1, 5, floorY(1));
    await spawn(game, 2, 5, 9);
    await _run(game, 1.5);
    expect(game.mergeDetector.touchingPairCount, 1);
    a.removeFromParent();
    await game.ready();
    expect(game.creatures, hasLength(1));
    expect(game.mergeDetector.touchingPairCount, 0);
    await _run(game, 1);
    expect(detected, isEmpty);
  });
}
