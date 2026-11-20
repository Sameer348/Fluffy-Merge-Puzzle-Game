import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/motion.dart';
import '../../../game/models/creature_spec.dart';
import '../../../game/rendering/creature_renderer.dart';

/// The home-screen hero: Fluffy, a crowned white kitty puff, peeking over a
/// grassy earthen ledge with its paws on the edge. Breathes, sways, and
/// squishes with a wink when tapped.
///
/// One [Ticker] → [ValueNotifier] → painter repaint; no widget rebuilds.
class HomeMascot extends StatefulWidget {
  const HomeMascot({super.key, this.onPoke});

  final VoidCallback? onPoke;

  @override
  State<HomeMascot> createState() => _HomeMascotState();
}

class _HomeMascotState extends State<HomeMascot>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  double _pokeAt = -10;
  bool _static = false;

  void _onTick(Duration elapsed) => _time.value = elapsed.inMicroseconds / 1e6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static = reduceMotion(context);
    if (_static) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _poke() {
    _pokeAt = _time.value;
    widget.onPoke?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fluffy, the Fluffy Merge mascot. Tap to poke.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _poke,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _MascotPainter(_time, () => _pokeAt, _static),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.time, this.pokeAt, this.isStatic) : super(repaint: time);

  final ValueNotifier<double> time;
  final double Function() pokeAt;
  final bool isStatic;

  static const CreatureSpec _hero = CreatureCatalog.mascot;
  static final Paint _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final top = CreatureRenderer.topExtent(_hero);
    // The whole face sits above the ledge; only the belly is hidden behind
    // it and the paws rest on its edge. Height budget (in r): ears/crown
    // [top] + face down to the ledge (0.5) + ledge (0.8).
    final r = math.min(size.width / 3.3, size.height / (top + 1.3));
    final cx = size.width / 2;
    final ledgeTop = size.height - r * 0.8;
    final heroCenter = Offset(cx, ledgeTop - r * 0.5);

    // Soft glow behind the hero.
    _p.shader = RadialGradient(
      colors: [
        AppColors.white.withValues(alpha: 0.8),
        AppColors.white.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: heroCenter, radius: r * 1.9));
    canvas.drawCircle(heroCenter, r * 1.9, _p);
    _p.shader = null;

    var sx = 1.0, sy = 1.0, sway = 0.0;
    var ex = CreatureExpression.excited; // big happy "^ ^" grin
    if (!isStatic) {
      final breath = math.sin(t * 2.2);
      sy = 1 + 0.03 * breath;
      sx = 1 - 0.02 * breath;
      sway = math.sin(t * 0.9) * 0.05;
      final dt = t - pokeAt();
      if (dt >= 0 && dt < 0.9) {
        final wobble = math.exp(-5 * dt) * math.cos(dt * 18);
        sy *= 1 - 0.18 * wobble;
        sx *= 1 + 0.14 * wobble;
        ex = dt < 0.5 ? CreatureExpression.squished : CreatureExpression.wink;
      }
    }

    canvas.save();
    canvas.translate(heroCenter.dx, heroCenter.dy);
    canvas.rotate(sway);
    CreatureRenderer.paint(
      canvas,
      _hero,
      r,
      scaleX: sx,
      scaleY: sy,
      expression: ex,
      shadow: false,
    );
    canvas.restore();

    _ledge(canvas, size, cx, ledgeTop, r);
    _paws(canvas, cx, ledgeTop, r);
  }

  /// Earthen block with a grassy, bumpy top and a few flowers.
  void _ledge(Canvas c, Size size, double cx, double top, double r) {
    final w = math.min(size.width * 0.98, r * 3.6);
    final rect = Rect.fromLTRB(
      cx - w / 2,
      top,
      cx + w / 2,
      size.height + r * 0.3,
    );
    final block = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.35));
    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.dirt, AppColors.dirtDark],
    ).createShader(rect);
    c.drawRRect(block, _p);
    _p.shader = null;

    // Stone/brick hints.
    _p.color = AppColors.dirtDark.withValues(alpha: 0.35);
    for (var i = 0; i < 5; i++) {
      final x = rect.left + w * (0.12 + i * 0.19);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            top + r * 0.42 + (i.isEven ? 0 : r * 0.18),
            w * 0.12,
            r * 0.1,
          ),
          Radius.circular(r * 0.05),
        ),
        _p,
      );
    }

    // Grass lip with scalloped edge.
    final grass = Path()..moveTo(rect.left, top + r * 0.08);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final x0 = rect.left + w * i / n, x1 = rect.left + w * (i + 1) / n;
      grass.quadraticBezierTo(
        (x0 + x1) / 2,
        top + r * 0.32,
        x1,
        top + r * 0.08,
      );
    }
    grass
      ..lineTo(rect.right, top - r * 0.02)
      ..quadraticBezierTo(cx, top - r * 0.12, rect.left, top - r * 0.02)
      ..close();
    _p.color = AppColors.grass;
    c.drawPath(grass, _p);

    // Flowers on the ledge corners.
    for (final (fx, col) in const [
      (0.08, Color(0xFFFF9EC4)),
      (0.16, Color(0xFFFFFFFF)),
      (0.86, Color(0xFFFFD86B)),
      (0.93, Color(0xFFFF9EC4)),
    ]) {
      final at = Offset(rect.left + w * fx, top + r * 0.02);
      final fr = r * 0.07;
      _p.color = col;
      for (var k = 0; k < 5; k++) {
        final a = k * math.pi * 2 / 5;
        c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * fr, fr * 0.85, _p);
      }
      _p.color = const Color(0xFFFFC94A);
      c.drawCircle(at, fr * 0.7, _p);
    }
  }

  /// Two little white paws resting on the ledge edge.
  void _paws(Canvas c, double cx, double top, double r) {
    for (final s in const [-1.0, 1.0]) {
      final at = Offset(cx + s * r * 0.48, top + r * 0.02);
      final paw = Rect.fromCenter(
        center: at,
        width: r * 0.42,
        height: r * 0.28,
      );
      _p.color = _hero.body;
      c.drawOval(paw, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = _hero.shade;
      c.drawOval(paw, _p);
      // Toe lines.
      for (final dx in const [-0.07, 0.07]) {
        c.drawLine(
          at + Offset(r * dx, -r * 0.02),
          at + Offset(r * dx, r * 0.07),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.isStatic != isStatic;
}
