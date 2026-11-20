import 'package:flutter/widgets.dart';

import '../../game/models/creature_spec.dart';
import '../../game/rendering/creature_renderer.dart';

/// Static (non-animated) creature for cards, dialogs and the collection.
class CreatureView extends StatelessWidget {
  const CreatureView({
    super.key,
    required this.spec,
    required this.size,
    this.expression = CreatureExpression.happy,
    this.silhouette = false,
  });

  final CreatureSpec spec;
  final double size;
  final CreatureExpression expression;
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: silhouette ? 'Locked creature' : spec.name,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _CreaturePainter(spec, expression, silhouette),
      ),
    );
  }
}

class _CreaturePainter extends CustomPainter {
  _CreaturePainter(this.spec, this.expression, this.silhouette);

  final CreatureSpec spec;
  final CreatureExpression expression;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit body + accessory headroom + ground shadow into the box.
    final top = CreatureRenderer.topExtent(spec);
    final r = size.height / (top + 1.1);
    canvas.translate(size.width / 2, r * top);
    CreatureRenderer.paint(
      canvas,
      spec,
      r,
      expression: expression,
      silhouette: silhouette,
    );
  }

  @override
  bool shouldRepaint(_CreaturePainter old) =>
      old.spec != spec ||
      old.expression != expression ||
      old.silhouette != silhouette;
}
