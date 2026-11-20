import 'dart:ui';

import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/rendering/creature_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'catalog has 12 levels, strictly growing radius, unique accessories',
    () {
      const all = CreatureCatalog.all;
      expect(all, hasLength(12));
      for (var i = 0; i < all.length; i++) {
        expect(all[i].level, i + 1);
        if (i > 0) expect(all[i].radius, greaterThan(all[i - 1].radius));
      }
      expect(all.map((c) => c.accessory).toSet(), hasLength(12));
      expect(all.map((c) => c.body).toSet(), hasLength(12));
      expect(CreatureCatalog.byLevel(99).level, 12);
      expect(CreatureCatalog.byLevel(0).level, 1);
    },
  );

  test('every creature × expression (and silhouette) paints without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final spec in CreatureCatalog.all) {
      for (final ex in CreatureExpression.values) {
        for (final blink in const [0.0, 0.5, 1.0]) {
          CreatureRenderer.paint(
            canvas,
            spec,
            40,
            expression: ex,
            blink: blink,
            scaleX: 1.1,
            scaleY: 0.9,
          );
        }
      }
      CreatureRenderer.paint(canvas, spec, 40, silhouette: true);
      // Tiny world-unit radius, as used inside the physics world.
      CreatureRenderer.paint(canvas, spec, spec.radius);
    }
    recorder.endRecording().dispose();
  });
}
