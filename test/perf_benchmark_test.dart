import 'dart:ui';

import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/rendering/creature_renderer.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame-cost benchmarks. Tests run unoptimized (JIT, debug asserts on),
/// so absolute numbers are pessimistic; they're for before/after
/// comparisons and catching big regressions. Run alone to see numbers:
///   flutter test test/perf_benchmark_test.dart
Future<List<int>> _pixels(
  CreatureSpec s,
  double r, {
  bool silhouette = false,
}) async {
  final rec = PictureRecorder();
  final canvas = Canvas(rec)..translate(r * 2, r * 2);
  CreatureRenderer.paint(canvas, s, r, blink: 0.3, silhouette: silhouette);
  final img = await rec.endRecording().toImage((r * 4).ceil(), (r * 4).ceil());
  final data = await img.toByteData();
  img.dispose();
  return data!.buffer.asUint8List().toList();
}

void main() {
  test('cached layers draw exactly what a fresh draw does', () async {
    for (final s in CreatureCatalog.all) {
      CreatureRenderer.clearCache();
      final fresh = await _pixels(s, 30);
      final cached = await _pixels(s, 30); // replayed from the cache
      expect(cached, fresh, reason: s.name);
      expect(fresh.any((b) => b != 0), isTrue, reason: 'drew something');
    }
    final before = CreatureRenderer.cachedLayerCount;
    await _pixels(CreatureCatalog.byLevel(3), 30, silhouette: true);
    expect(CreatureRenderer.cachedLayerCount, before + 2, reason: 'own keys');
    CreatureRenderer.clearCache();
    expect(CreatureRenderer.cachedLayerCount, 0);
  });

  test('drawing a full jar of creatures (Dart-side frame cost)', () {
    // 40 creatures across all levels at in-game sizes (world units × zoom).
    const zoom = 40.0;
    final specs = [
      for (var i = 0; i < 40; i++)
        CreatureCatalog.byLevel(1 + i % CreatureCatalog.maxLevel),
    ];

    void frame(int f) {
      final rec = PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < specs.length; i++) {
        final s = specs[i];
        canvas
          ..save()
          ..translate((i % 8) * 50.0, (i ~/ 8) * 60.0);
        CreatureRenderer.paint(
          canvas,
          s,
          s.radius * zoom,
          // Breathing + blink change every frame, like in game.
          scaleX: 1 - 0.018 * (f % 10) / 10,
          scaleY: 1 + 0.025 * (f % 10) / 10,
          blink: (f % 30) / 30,
          expression: CreatureExpression.values[(i + f ~/ 60) % 3],
        );
        canvas.restore();
      }
      rec.endRecording().dispose();
    }

    for (var f = 0; f < 60; f++) {
      frame(f); // warm up caches and the JIT
    }
    const frames = 600;
    final sw = Stopwatch()..start();
    for (var f = 0; f < frames; f++) {
      frame(f);
    }
    final perFrame = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('BENCH draw 40 creatures: ${perFrame.toStringAsFixed(3)} ms/frame');
    // Generous: a debug-mode regression guard, not a target.
    expect(perFrame, lessThan(8));
  });

  testWithGame<FluffyGame>(
    'stepping a busy jar (physics + merges + game logic)',
    () => FluffyGame(seed: 9),
    (game) async {
      try {
        await game.ready();
        // A full pile of mixed creatures; neighbours mostly differ, so it
        // stays busy (some merges, lots of contacts) instead of collapsing.
        for (var i = 0; i < 40; i++) {
          game.spawnCreature(
            1 + (i * 5) % 7,
            Vector2(0.9 + (i % 7) * 1.35, 13 - (i ~/ 7) * 1.7),
          );
        }
        await game.ready();
        for (var i = 0; i < 60; i++) {
          game.update(1 / 60);
        }
        await game.ready();
        const frames = 600;
        final sw = Stopwatch()..start();
        for (var i = 0; i < frames; i++) {
          game.update(1 / 60);
          if (i % 30 == 0) await game.ready();
        }
        final perFrame = sw.elapsedMicroseconds / frames / 1000;
        // ignore: avoid_print
        print(
          'BENCH step busy jar (${game.creatures.length} left): '
          '${perFrame.toStringAsFixed(3)} ms/frame',
        );
        expect(perFrame, lessThan(8));
      } finally {
        game.disposeSession();
      }
    },
  );
}
