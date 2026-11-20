import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../game/models/creature_spec.dart';
import '../../game/rendering/creature_renderer.dart';

/// A creature that breathes and blinks, driven by a shared [time] notifier
/// (one ticker for a whole grid instead of one per card). Pass a constant
/// notifier (or reduce motion) for a still pose.
class LivingCreature extends StatelessWidget {
  const LivingCreature({
    super.key,
    required this.spec,
    required this.time,
    required this.size,
    this.silhouette = false,
    this.expression = CreatureExpression.happy,
  });

  final CreatureSpec spec;
  final ValueListenable<double> time;
  final double size;
  final bool silhouette;
  final CreatureExpression expression;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: silhouette ? 'Undiscovered creature' : spec.name,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _LivingPainter(spec, time, silhouette, expression),
        ),
      ),
    );
  }
}

class _LivingPainter extends CustomPainter {
  _LivingPainter(this.spec, this.time, this.silhouette, this.expression)
    : super(repaint: time);

  final CreatureSpec spec;
  final ValueListenable<double> time;
  final bool silhouette;
  final CreatureExpression expression;

  @override
  void paint(Canvas canvas, Size size) {
    // Each level gets its own phase so a grid doesn't breathe in unison.
    final t = time.value + spec.level * 0.77;
    final top = CreatureRenderer.topExtent(spec);
    final r = size.height / (top + 1.1);
    final breath = silhouette ? 0.0 : math.sin(t * 2.2);
    final blinkPhase = (t + spec.level * 1.3) % 4.2;
    final blink = silhouette || blinkPhase > 0.16
        ? 0.0
        : math.sin(blinkPhase / 0.16 * math.pi);
    canvas.translate(size.width / 2, r * top);
    CreatureRenderer.paint(
      canvas,
      spec,
      r,
      expression: expression,
      scaleX: 1 - 0.02 * breath,
      scaleY: 1 + 0.03 * breath,
      blink: blink,
      silhouette: silhouette,
    );
  }

  @override
  bool shouldRepaint(_LivingPainter old) =>
      old.spec != spec ||
      old.silhouette != silhouette ||
      old.expression != expression ||
      old.time != time;
}
