import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/constants/game_constants.dart';
import 'physics_config.dart';

/// Static jar body: left wall, rounded bottom-left corner, floor, rounded
/// bottom-right corner, right wall.
///
/// Box2D v3 chains are one-sided: a segment collides only on the right of
/// its direction ((dx, dy) → normal (dy, -dx)). Walking down the left wall,
/// along the floor, and up the right wall makes every normal point into the
/// jar. An open chain's first and last segments are "ghosts" used only for
/// smooth contacts, so an extra point is added at each end.
class JarWalls extends BodyComponent {
  JarWalls() : super(renderBody: false);

  /// The chain points, exposed for tests.
  static List<Vector2> chainPoints() {
    const w = GameConstants.worldWidth;
    const h = GameConstants.worldHeight;
    const cr = PhysicsConfig.cornerRadius;
    const n = PhysicsConfig.cornerSegments;
    const top = PhysicsConfig.wallTop;

    final pts = <Vector2>[
      Vector2(0, top - 2), // ghost
      Vector2(0, top),
      Vector2(0, h - cr),
    ];
    // Bottom-left corner: center (cr, h - cr), angle π → π/2 (y-down).
    for (var i = 1; i < n; i++) {
      final a = math.pi - (math.pi / 2) * i / n;
      pts.add(Vector2(cr + cr * math.cos(a), h - cr + cr * math.sin(a)));
    }
    pts
      ..add(Vector2(cr, h))
      ..add(Vector2(w - cr, h));
    // Bottom-right corner: center (w - cr, h - cr), angle π/2 → 0.
    for (var i = 1; i < n; i++) {
      final a = math.pi / 2 - (math.pi / 2) * i / n;
      pts.add(Vector2(w - cr + cr * math.cos(a), h - cr + cr * math.sin(a)));
    }
    pts
      ..add(Vector2(w, h - cr))
      ..add(Vector2(w, top))
      ..add(Vector2(w, top - 2)); // ghost
    return pts;
  }

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(userData: this));
    body.createChain(
      ChainDef(
        points: chainPoints(),
        materials: [SurfaceMaterial(friction: PhysicsConfig.wallFriction)],
      ),
    );
    return body;
  }
}
