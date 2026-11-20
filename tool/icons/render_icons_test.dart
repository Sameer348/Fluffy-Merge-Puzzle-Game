// Renders the app icon masters from the game's own procedural art.
//
//   flutter test tool/icons/render_icons_test.dart
//   python3 tool/icons/make_icons.py
//
// Outputs (1024 px, then resized by make_icons.py) go to build/icon_src/.
import 'dart:io';
import 'dart:ui';

import 'package:fluffy_merge/core/constants/app_colors.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/rendering/creature_renderer.dart';
import 'package:flutter/painting.dart'
    show Alignment, LinearGradient, RadialGradient;
import 'package:flutter_test/flutter_test.dart';

const double _size = 1024;
const CreatureSpec _hero = CreatureCatalog.mascot;

/// Sky like the home screen, a bit richer so it reads at 48 px.
void _background(Canvas c, double s) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.skyTop, AppColors.skyMid, AppColors.skyHorizon],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
  // A few soft sparkles in the corners.
  final dot = Paint()..color = const Color(0xCCFFFFFF);
  for (final (x, y, r) in const [
    (0.16, 0.18, 0.018),
    (0.84, 0.14, 0.012),
    (0.88, 0.80, 0.016),
    (0.12, 0.84, 0.010),
  ]) {
    c.drawCircle(Offset(x * s, y * s), r * s, dot);
  }
}

/// The crowned kitty, centered with a soft glow, its full height
/// (crown to chin) filling [fill] of the canvas.
void _drawHero(Canvas c, double s, {required double fill, bool mono = false}) {
  final top = CreatureRenderer.topExtent(_hero);
  final r = fill * s / (top + 1.0);
  // Vertically center the crown-to-chin box.
  final cy = s / 2 + (top - 1.0) / 2 * r;
  final center = Offset(s / 2, cy);
  if (!mono) {
    c.drawCircle(
      center,
      r * 1.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.white.withValues(alpha: 0.85),
            AppColors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.7)),
    );
  }
  c
    ..save()
    ..translate(center.dx, center.dy);
  CreatureRenderer.paint(
    c,
    _hero,
    r,
    expression: CreatureExpression.excited,
    shadow: false,
    silhouette: mono,
  );
  c.restore();
}

Future<void> _write(String name, void Function(Canvas c, double s) draw) async {
  final rec = PictureRecorder();
  draw(Canvas(rec), _size);
  final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
  final png = await img.toByteData(format: ImageByteFormat.png);
  img.dispose();
  final out = File('build/icon_src/$name.png')..createSync(recursive: true);
  out.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render icon masters', () async {
    // Full icon (iOS, Play Store, legacy Android): background + hero.
    await _write('icon_full', (c, s) {
      _background(c, s);
      _drawHero(c, s, fill: 0.8);
    });
    // Android adaptive icon layers. The launcher masks to a circle/squircle
    // showing the middle 72/108 and may move the foreground a little, so
    // the hero stays inside the 66/108 safe zone.
    await _write('adaptive_background', _background);
    await _write('adaptive_foreground', (c, s) {
      _drawHero(c, s, fill: 0.56);
    });
    // Android 13 themed icon: only the alpha channel is used.
    await _write('adaptive_monochrome', (c, s) {
      _drawHero(c, s, fill: 0.56, mono: true);
    });
    expect(File('build/icon_src/icon_full.png').existsSync(), isTrue);
  });
}
