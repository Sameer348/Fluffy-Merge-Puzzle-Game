import 'dart:math' as math;
import 'dart:ui';

import '../models/creature_spec.dart';

/// Procedural, asset-free renderer for plush "Puff" creatures.
///
/// Pure `dart:ui` canvas code so the exact same drawing is used by Flutter
/// widgets (menu mascot, collection cards) and by the Flame game.
/// The creature is drawn centered at the canvas origin with radius [r];
/// callers translate the canvas to position it.
///
/// Paths and gradient shaders are cached per (level, radius) so steady-state
/// frames allocate almost nothing.
abstract final class CreatureRenderer {
  static const Color _ink = Color(0xFF4A3F45);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _blush = Color(0xFFFF7F9B);
  static const Color _gold = Color(0xFFFFD166);
  static const Color _goldDeep = Color(0xFFE0A93A);
  static const Color _leaf = Color(0xFF8CCF8A);
  static const Color _leafDeep = Color(0xFF5FA65D);
  static const Color _coral = Color(0xFFFF8FA3);
  static const Color _coralDeep = Color(0xFFDB6F86);
  static const Color _silhouette = Color(0xFFD9CBC4);

  static final Map<int, Path> _paths = {};
  static final Map<int, Shader> _shaders = {};

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _bodyPaint = Paint()..isAntiAlias = true;

  /// Draws one creature.
  ///
  /// [scaleX]/[scaleY] give squash-and-stretch (bottom stays planted).
  /// [blink] 0..1 closes the eyes. [silhouette] draws a locked, faceless
  /// shape for the collection screen.
  static void paint(
    Canvas canvas,
    CreatureSpec spec,
    double r, {
    CreatureExpression expression = CreatureExpression.happy,
    double scaleX = 1,
    double scaleY = 1,
    double blink = 0,
    bool shadow = true,
    bool silhouette = false,
  }) {
    if (shadow) {
      _fill.color = const Color(0x224A3F45);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, r * 0.93),
          width: r * 1.55 * scaleX,
          height: r * 0.26,
        ),
        _fill,
      );
    }

    canvas.save();
    canvas.translate(0, r * 0.93 * (1 - scaleY));
    canvas.scale(scaleX, scaleY);

    final mono = silhouette ? _silhouette : null;
    _drawEars(canvas, spec, r, mono);
    _drawBackAccessory(canvas, spec, r, mono);

    final body = _bodyPath(spec, r);
    if (silhouette) {
      _fill.color = _silhouette;
      canvas.drawPath(body, _fill);
    } else {
      _bodyPaint.shader = _bodyShader(spec, r);
      canvas.drawPath(body, _bodyPaint);
      _stroke
        ..color = spec.shade
        ..strokeWidth = r * 0.07;
      canvas.drawPath(body, _stroke);
      _drawFur(canvas, spec, r);
      _drawHighlight(canvas, r);
      _drawFace(canvas, spec, r, expression, blink);
    }

    _drawFrontAccessory(canvas, spec, r, mono);
    canvas.restore();
  }

  /// Visual extent above the body center (for sizing widgets): some
  /// accessories (halo, rainbow, star) poke out above the radius.
  static double topExtent(CreatureSpec spec) {
    final acc = switch (spec.accessory) {
      CreatureAccessory.halo ||
      CreatureAccessory.rainbow ||
      CreatureAccessory.star => 1.45,
      CreatureAccessory.leaf || CreatureAccessory.cloud => 1.25,
      _ => 1.12,
    };
    final ear = switch (spec.ears) {
      EarStyle.none => 0.0,
      EarStyle.cat => 1.35,
      EarStyle.bunny => 1.75,
    };
    return math.max(acc, ear);
  }

  // ---------------------------------------------------------------------------
  // Body

  static int _key(CreatureSpec spec, double r, [int salt = 0]) =>
      salt * 100000000 + spec.level * 1000000 + (r * 100).round();

  static Path _bodyPath(CreatureSpec spec, double r) {
    if (_paths.length > 400) _paths.clear();
    return _paths.putIfAbsent(_key(spec, r), () {
      // Plush fur edge: twice as many tufts as bumps, alternating big and
      // small, with a slight deterministic wobble so it looks hand-made.
      final path = Path();
      final base = r * 0.93;
      final n = spec.bumps * 2;
      final step = 2 * math.pi / n;
      for (var i = 0; i <= n; i++) {
        final a = -math.pi / 2 + i * step;
        final x = math.cos(a) * base, y = math.sin(a) * base;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final wobble = 0.85 + 0.3 * ((i * 37 + spec.level * 11) % 7) / 6;
          final puff = (i.isEven ? spec.puff : spec.puff * 0.55) * wobble;
          final cr = base * (1 + puff);
          final m = a - step / 2;
          path.quadraticBezierTo(math.cos(m) * cr, math.sin(m) * cr, x, y);
        }
      }
      return path..close();
    });
  }

  static Shader _bodyShader(CreatureSpec spec, double r) {
    if (_shaders.length > 400) _shaders.clear();
    return _shaders.putIfAbsent(_key(spec, r), () {
      final g = spec.gradient;
      if (g != null) {
        return Gradient.linear(Offset(-r, -r), Offset(r, r), g, [
          for (var i = 0; i < g.length; i++) i / (g.length - 1),
        ]);
      }
      return Gradient.radial(
        Offset(-r * 0.3, -r * 0.4),
        r * 1.5,
        [spec.light, spec.body, spec.shade],
        const [0, 0.55, 1],
      );
    });
  }

  static void _drawHighlight(Canvas canvas, double r) {
    canvas.save();
    canvas.translate(-r * 0.38, -r * 0.5);
    canvas.rotate(-0.6);
    _fill.color = const Color(0x8CFFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.36, height: r * 0.2),
      _fill,
    );
    canvas.restore();
    _fill.color = const Color(0x73FFFFFF);
    canvas.drawCircle(Offset(-r * 0.64, -r * 0.18), r * 0.055, _fill);
  }

  // ---------------------------------------------------------------------------
  // Face

  static void _drawFace(
    Canvas canvas,
    CreatureSpec spec,
    double r,
    CreatureExpression ex,
    double blink,
  ) {
    final er = r * 0.118 * spec.eyeScale;
    final eyeY = -r * 0.02;
    final dx = r * 0.31;
    final left = Offset(-dx, eyeY), right = Offset(dx, eyeY);

    // Cheeks
    final bigBlush = spec.accessory == CreatureAccessory.blush;
    _fill.color = _blush.withValues(alpha: bigBlush ? 0.55 : 0.42);
    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * r * 0.54, r * 0.22),
          width: r * (bigBlush ? 0.34 : 0.27),
          height: r * (bigBlush ? 0.19 : 0.15),
        ),
        _fill,
      );
    }
    if (spec.freckles) {
      _fill.color = spec.shade.withValues(alpha: 0.7);
      for (final s in const [-1.0, 1.0]) {
        for (final o in const [
          Offset(-0.07, -0.03),
          Offset(0.06, -0.04),
          Offset(0, 0.04),
        ]) {
          canvas.drawCircle(
            Offset(s * r * 0.52 + o.dx * r, r * 0.2 + o.dy * r),
            r * 0.018,
            _fill,
          );
        }
      }
    }

    _stroke
      ..color = _ink
      ..strokeWidth = r * 0.055;
    _fill.color = _ink;

    switch (ex) {
      case CreatureExpression.happy:
        _openEye(canvas, left, er, blink, spec, -1);
        _openEye(canvas, right, er, blink, spec, 1);
      case CreatureExpression.surprised:
        _roundEye(canvas, left, er * 1.25, spec);
        _roundEye(canvas, right, er * 1.25, spec);
      case CreatureExpression.squished:
        _chevron(canvas, left, er, 1);
        _chevron(canvas, right, er, -1);
      case CreatureExpression.excited:
        _arcEye(canvas, left, er);
        _arcEye(canvas, right, er);
      case CreatureExpression.worried:
        _openEye(canvas, left, er * 0.85, blink, spec, -1);
        _openEye(canvas, right, er * 0.85, blink, spec, 1);
        _stroke.strokeWidth = r * 0.045;
        canvas.drawLine(
          Offset(left.dx - er * 1.1, eyeY - er * 1.7),
          Offset(left.dx + er * 1.0, eyeY - er * 2.5),
          _stroke,
        );
        canvas.drawLine(
          Offset(right.dx + er * 1.1, eyeY - er * 1.7),
          Offset(right.dx - er * 1.0, eyeY - er * 2.5),
          _stroke,
        );
        _stroke.strokeWidth = r * 0.055;
      case CreatureExpression.wink:
        _openEye(canvas, left, er, 0, spec, -1);
        _arcEye(canvas, right, er);
    }

    _drawMouth(canvas, spec, r, ex);
  }

  static void _openEye(
    Canvas canvas,
    Offset c,
    double er,
    double blink,
    CreatureSpec spec,
    double side,
  ) {
    if (blink > 0.85) {
      final p = Path()
        ..moveTo(c.dx - er, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + er * 0.9, c.dx + er, c.dy);
      canvas.drawPath(p, _stroke);
      return;
    }
    _fill.color = _ink;
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: er * 1.7,
        height: er * 2.1 * (1 - blink * 0.85),
      ),
      _fill,
    );
    if (spec.lashes) {
      canvas.drawLine(
        Offset(c.dx + side * er * 0.75, c.dy - er * 0.75),
        Offset(c.dx + side * er * 1.35, c.dy - er * 1.2),
        _stroke,
      );
    }
    if (blink < 0.5) _glints(canvas, c, er, spec);
  }

  static void _roundEye(Canvas canvas, Offset c, double er, CreatureSpec spec) {
    _fill.color = _ink;
    canvas.drawCircle(c, er, _fill);
    _glints(canvas, c, er * 0.9, spec);
  }

  static void _glints(Canvas canvas, Offset c, double er, CreatureSpec spec) {
    // Big + small catch-lights for the sparkly kawaii look; sparkle-eyed
    // creatures get a third twinkle.
    _fill.color = _white;
    canvas.drawCircle(c + Offset(er * 0.3, -er * 0.42), er * 0.42, _fill);
    canvas.drawCircle(c + Offset(-er * 0.32, er * 0.42), er * 0.18, _fill);
    if (spec.sparkleEyes) {
      canvas.drawCircle(c + Offset(er * 0.42, er * 0.2), er * 0.12, _fill);
    }
    _fill.color = _ink;
  }

  /// "^" happy-closed eye.
  static void _arcEye(Canvas canvas, Offset c, double er) {
    final p = Path()
      ..moveTo(c.dx - er, c.dy + er * 0.35)
      ..quadraticBezierTo(c.dx, c.dy - er * 1.0, c.dx + er, c.dy + er * 0.35);
    canvas.drawPath(p, _stroke);
  }

  /// ">" / "<" squeezed eye. [dir] 1 points right, -1 points left.
  static void _chevron(Canvas canvas, Offset c, double er, double dir) {
    final p = Path()
      ..moveTo(c.dx - dir * er * 0.8, c.dy - er * 0.9)
      ..lineTo(c.dx + dir * er * 0.7, c.dy)
      ..lineTo(c.dx - dir * er * 0.8, c.dy + er * 0.9);
    canvas.drawPath(p, _stroke);
  }

  static void _drawMouth(
    Canvas canvas,
    CreatureSpec spec,
    double r,
    CreatureExpression ex,
  ) {
    final y = r * 0.19;
    final mw = r * 0.12;
    final p = Path();
    switch (ex) {
      case CreatureExpression.surprised:
        _fill.color = _ink;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, y + mw * 0.2),
            width: mw * 0.9,
            height: mw * 1.1,
          ),
          _fill,
        );
        return;
      case CreatureExpression.excited:
        p
          ..moveTo(-mw * 1.1, y - mw * 0.1)
          ..lineTo(mw * 1.1, y - mw * 0.1)
          ..quadraticBezierTo(0, y + mw * 1.9, -mw * 1.1, y - mw * 0.1)
          ..close();
        _fill.color = _ink;
        canvas.drawPath(p, _fill);
        _fill.color = _blush;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, y + mw * 0.6),
            width: mw * 0.9,
            height: mw * 0.45,
          ),
          _fill,
        );
        return;
      case CreatureExpression.squished:
        p
          ..moveTo(-mw * 0.8, y)
          ..quadraticBezierTo(-mw * 0.4, y - mw * 0.35, 0, y)
          ..quadraticBezierTo(mw * 0.4, y + mw * 0.35, mw * 0.8, y);
      case CreatureExpression.worried:
        p
          ..moveTo(-mw, y + mw * 0.3)
          ..quadraticBezierTo(-mw * 0.5, y - mw * 0.25, 0, y + mw * 0.1)
          ..quadraticBezierTo(mw * 0.5, y + mw * 0.45, mw, y);
      case CreatureExpression.happy:
      case CreatureExpression.wink:
        if (spec.catMouth) {
          p
            ..moveTo(-mw, y)
            ..quadraticBezierTo(-mw * 0.5, y + mw * 0.85, 0, y)
            ..quadraticBezierTo(mw * 0.5, y + mw * 0.85, mw, y);
        } else {
          p
            ..moveTo(-mw, y)
            ..quadraticBezierTo(0, y + mw * 1.15, mw, y);
        }
    }
    canvas.drawPath(p, _stroke);
  }

  // ---------------------------------------------------------------------------
  // Fur and ears

  /// A soft tuft on top of the head plus a few short light strokes inside
  /// the edge, so the body reads as fur rather than a flat disc.
  static void _drawFur(Canvas canvas, CreatureSpec spec, double r) {
    _stroke
      ..color = spec.light.withValues(alpha: 0.5)
      ..strokeWidth = r * 0.04;
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (0.95 + i * 0.16); // upper-left → right arc
      final p0 = Offset(math.cos(a), math.sin(a)) * (r * 0.8);
      final p1 = Offset(math.cos(a + 0.08), math.sin(a + 0.08)) * (r * 0.72);
      canvas.drawLine(p0, p1, _stroke);
    }
    // Head tuft: three little curls.
    _stroke
      ..color = spec.shade
      ..strokeWidth = r * 0.055;
    for (final (dx, h) in const [(-0.12, 0.16), (0.0, 0.22), (0.12, 0.15)]) {
      final tuft = Path()
        ..moveTo(r * dx - r * 0.04, -r * 0.9)
        ..quadraticBezierTo(
          r * dx,
          -r * (0.9 + h),
          r * dx + r * 0.07,
          -r * (0.88 + h * 0.6),
        );
      canvas.drawPath(tuft, _stroke);
    }
  }

  static void _drawEars(
    Canvas canvas,
    CreatureSpec spec,
    double r,
    Color? mono,
  ) {
    switch (spec.ears) {
      case EarStyle.none:
        return;
      case EarStyle.cat:
        for (final s in const [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(s * r * 0.2, -r * 0.82)
            ..quadraticBezierTo(s * r * 0.5, -r * 1.32, s * r * 0.72, -r * 1.18)
            ..quadraticBezierTo(s * r * 0.82, -r * 0.8, s * r * 0.8, -r * 0.5)
            ..close();
          _outlined(canvas, ear, spec.body, spec.shade, r * 0.06, mono);
          if (mono == null) {
            final inner = Path()
              ..moveTo(s * r * 0.36, -r * 0.82)
              ..quadraticBezierTo(
                s * r * 0.55,
                -r * 1.14,
                s * r * 0.68,
                -r * 1.06,
              )
              ..quadraticBezierTo(
                s * r * 0.72,
                -r * 0.84,
                s * r * 0.7,
                -r * 0.66,
              )
              ..close();
            _fill.color = _blush.withValues(alpha: 0.5);
            canvas.drawPath(inner, _fill);
          }
        }
      case EarStyle.bunny:
        for (final s in const [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(s * r * 0.36, -r * 0.95);
          canvas.rotate(s * 0.28);
          final ear = Path()
            ..addOval(
              Rect.fromCenter(
                center: Offset(0, -r * 0.28),
                width: r * 0.34,
                height: r * 0.8,
              ),
            );
          _outlined(canvas, ear, spec.body, spec.shade, r * 0.06, mono);
          if (mono == null) {
            _fill.color = _blush.withValues(alpha: 0.45);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(0, -r * 0.26),
                width: r * 0.15,
                height: r * 0.55,
              ),
              _fill,
            );
          }
          canvas.restore();
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Accessories

  static void _outlined(
    Canvas canvas,
    Path path,
    Color fill,
    Color line,
    double width,
    Color? mono,
  ) {
    _fill.color = mono ?? fill;
    canvas.drawPath(path, _fill);
    if (mono == null) {
      _stroke
        ..color = line
        ..strokeWidth = width;
      canvas.drawPath(path, _stroke);
    }
  }

  static void _drawBackAccessory(
    Canvas canvas,
    CreatureSpec spec,
    double r,
    Color? mono,
  ) {
    switch (spec.accessory) {
      case CreatureAccessory.ears:
        for (final s in const [-1.0, 1.0]) {
          final c = Offset(s * r * 0.52, -r * 0.7);
          final ear = Path()
            ..addOval(Rect.fromCircle(center: c, radius: r * 0.27));
          _outlined(canvas, ear, spec.body, spec.shade, r * 0.07, mono);
          if (mono == null) {
            _fill.color = _blush.withValues(alpha: 0.45);
            canvas.drawCircle(c + Offset(0, r * 0.02), r * 0.13, _fill);
          }
        }
      case CreatureAccessory.rainbow:
        const colors = [
          Color(0xFFFF8FA3),
          Color(0xFFFFD166),
          Color(0xFF8FD3C7),
          Color(0xFF8EC5FF),
          Color(0xFFB8A1FF),
        ];
        _stroke.strokeWidth = r * 0.075;
        for (var i = 0; i < colors.length; i++) {
          _stroke.color = mono ?? colors[i];
          final rr = r * (1.06 + i * 0.075);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(0, -r * 0.05), radius: rr),
            math.pi * 1.12,
            math.pi * 0.76,
            false,
            _stroke,
          );
        }
      default:
        break;
    }
  }

  static void _drawFrontAccessory(
    Canvas canvas,
    CreatureSpec spec,
    double r,
    Color? mono,
  ) {
    final w = r * 0.06;
    switch (spec.accessory) {
      case CreatureAccessory.ears:
      case CreatureAccessory.blush:
        break;
      case CreatureAccessory.leaf:
        _stroke
          ..color = mono ?? _leafDeep
          ..strokeWidth = w;
        canvas.drawLine(
          Offset(0, -r * 0.88),
          Offset(r * 0.04, -r * 1.08),
          _stroke,
        );
        canvas.save();
        canvas.translate(r * 0.2, -r * 1.1);
        canvas.rotate(-0.45);
        final leaf = Path()
          ..moveTo(-r * 0.2, 0)
          ..quadraticBezierTo(0, -r * 0.16, r * 0.2, 0)
          ..quadraticBezierTo(0, r * 0.16, -r * 0.2, 0)
          ..close();
        _outlined(canvas, leaf, _leaf, _leafDeep, w * 0.8, mono);
        canvas.restore();
      case CreatureAccessory.bow:
        canvas.save();
        canvas.translate(r * 0.5, -r * 0.72);
        canvas.rotate(0.25);
        for (final s in const [-1.0, 1.0]) {
          final loop = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(s * r * 0.32, -r * 0.24, s * r * 0.3, 0)
            ..quadraticBezierTo(s * r * 0.32, r * 0.24, 0, 0)
            ..close();
          _outlined(canvas, loop, _coral, _coralDeep, w * 0.8, mono);
        }
        _fill.color = mono ?? _coralDeep;
        canvas.drawCircle(Offset.zero, r * 0.07, _fill);
        canvas.restore();
      case CreatureAccessory.sparkle:
        _sparkle(canvas, Offset(r * 0.62, -r * 0.78), r * 0.2, mono ?? _gold);
        _sparkle(canvas, Offset(r * 0.86, -r * 0.48), r * 0.1, mono ?? _gold);
      case CreatureAccessory.crown:
        final bw = r * 0.5, h = r * 0.32, by = -r * 0.82;
        final crown = Path()
          ..moveTo(-bw / 2, by)
          ..lineTo(-bw / 2, by - h)
          ..lineTo(-bw / 4, by - h * 0.55)
          ..lineTo(0, by - h * 1.05)
          ..lineTo(bw / 4, by - h * 0.55)
          ..lineTo(bw / 2, by - h)
          ..lineTo(bw / 2, by)
          ..close();
        _outlined(canvas, crown, _gold, _goldDeep, w * 0.8, mono);
        if (mono == null) {
          _fill.color = _coral;
          canvas.drawCircle(Offset(0, by - h * 0.35), r * 0.05, _fill);
        }
      case CreatureAccessory.flower:
        final c = Offset(-r * 0.58, -r * 0.66);
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5 - math.pi / 2;
          final petal = Path()
            ..addOval(
              Rect.fromCircle(
                center: c + Offset(math.cos(a), math.sin(a)) * (r * 0.11),
                radius: r * 0.1,
              ),
            );
          _outlined(canvas, petal, _white, _coral, w * 0.6, mono);
        }
        _fill.color = mono ?? _gold;
        canvas.drawCircle(c, r * 0.075, _fill);
      case CreatureAccessory.star:
        _stroke
          ..color = mono ?? spec.shade
          ..strokeWidth = w * 0.8;
        final antenna = Path()
          ..moveTo(0, -r * 0.88)
          ..quadraticBezierTo(-r * 0.04, -r * 1.05, r * 0.08, -r * 1.16);
        canvas.drawPath(antenna, _stroke);
        _outlined(
          canvas,
          _starPath(Offset(r * 0.08, -r * 1.22), r * 0.17),
          _gold,
          _goldDeep,
          w * 0.7,
          mono,
        );
      case CreatureAccessory.cloud:
        for (final o in const [
          Offset(-0.16, -0.88),
          Offset(0.16, -0.88),
          Offset(0, -0.98),
        ]) {
          final puff = Path()
            ..addOval(Rect.fromCircle(center: o * r, radius: r * 0.14));
          _outlined(canvas, puff, _white, spec.shade, w * 0.7, mono);
        }
      case CreatureAccessory.halo:
        _stroke
          ..color = mono ?? _gold
          ..strokeWidth = r * 0.075;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -r * 1.15),
            width: r * 0.75,
            height: r * 0.2,
          ),
          _stroke,
        );
        _sparkle(canvas, Offset(-r * 0.62, -r * 1.05), r * 0.11, mono ?? _gold);
        _sparkle(canvas, Offset(r * 0.66, -r * 1.12), r * 0.08, mono ?? _gold);
      case CreatureAccessory.moon:
        final c = Offset(r * 0.52, -r * 0.76);
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.2)),
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(r * 0.09, -r * 0.06),
              radius: r * 0.17,
            ),
          ),
        );
        _outlined(
          canvas,
          moon,
          const Color(0xFFFFE9A8),
          _goldDeep,
          w * 0.6,
          mono,
        );
      case CreatureAccessory.rainbow:
        _sparkle(canvas, Offset(-r * 0.7, -r * 0.95), r * 0.12, mono ?? _white);
        _sparkle(canvas, Offset(r * 0.75, -r * 0.88), r * 0.09, mono ?? _gold);
    }
  }

  static void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    _fill.color = color;
    canvas.drawPath(p, _fill);
  }

  static Path _starPath(Offset c, double outer) {
    final inner = outer * 0.5;
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }
}
