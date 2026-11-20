import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/motion.dart';
import '../../features/shop/model/cosmetics.dart';
import '../../features/shop/shop_controller.dart';

/// Which layout of the storybook scene to paint.
enum SceneVariant {
  /// Big sky, castle on a floating island, hills at the bottom.
  menu,

  /// Sky and a grassy mound at the bottom for the jar to sit on.
  game,
}

/// Fully procedural storybook backdrop (no image assets): sky gradient,
/// drifting clouds, hot-air balloons, a little castle, rolling hills and
/// flowers, plus a cloud bank along the bottom.
///
/// Static layers are cached in a [Picture] per size; only the clouds and
/// balloons move, driven by a ticker → repaint (no widget rebuilds).
///
/// The palette comes from the equipped background in the shop unless a
/// [theme] is given (e.g. shop previews).
class SceneBackground extends ConsumerStatefulWidget {
  const SceneBackground({
    super.key,
    this.variant = SceneVariant.menu,
    this.theme,
  });

  final SceneVariant variant;
  final SceneTheme? theme;

  @override
  ConsumerState<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends ConsumerState<SceneBackground>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMicroseconds / 1e6,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
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

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(
            _time,
            widget.variant,
            widget.theme ?? ref.watch(equippedSceneProvider),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.time, this.variant, this.theme) : super(repaint: time);

  final ValueNotifier<double> time;
  final SceneVariant variant;
  final SceneTheme theme;

  // Cached static layers, shared across instances, keyed by size+variant.
  static final Map<String, Picture> _cache = {};
  static final Paint _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key =
        '${theme.id}:${variant.name}:${size.width.round()}x${size.height.round()}';
    if (_cache.length > 6) {
      for (final pic in _cache.values) {
        pic.dispose();
      }
      _cache.clear();
    }
    final back = _cache.putIfAbsent(key, () => _record(size, front: false));
    final front = _cache.putIfAbsent(
      '$key:f',
      () => _record(size, front: true),
    );

    canvas.drawPicture(back);
    _drawMoving(canvas, size, time.value);
    canvas.drawPicture(front);
  }

  Picture _record(Size size, {required bool front}) {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    if (front) {
      _paintFront(c, size);
    } else {
      _paintBack(c, size);
    }
    return rec.endRecording();
  }

  // ---------------------------------------------------------------------------
  // Static back layer: sky, sun glow, castle, far hills.

  void _paintBack(Canvas c, Size s) {
    final w = s.width, h = s.height;
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [theme.skyTop, theme.skyMid, theme.skyHorizon],
      stops: const [0, 0.5, 0.85],
    ).createShader(Offset.zero & s);
    c.drawRect(Offset.zero & s, _p);
    _p.shader = null;

    // Soft sun glow, upper right.
    _p.shader =
        RadialGradient(
          colors: [
            theme.sun.withValues(alpha: 0.9),
            theme.sun.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.85, h * 0.08), radius: w * 0.55),
        );
    c.drawCircle(Offset(w * 0.85, h * 0.08), w * 0.55, _p);
    _p.shader = null;

    if (variant == SceneVariant.menu) {
      _castleIsland(c, Offset(w * 0.12, h * 0.2), w * 0.2);
    } else {
      _castleIsland(c, Offset(w * 0.1, h * 0.14), w * 0.14);
    }

    // Far hills.
    final hillTop = variant == SceneVariant.menu ? h * 0.7 : h * 0.8;
    if (theme.stars) _stars(c, s);
    _hills(c, s, hillTop, theme.hillFar, 3, 0.04);
  }

  // ---------------------------------------------------------------------------
  // Static front layer: near hills / mound, flowers, bottom cloud bank.

  void _paintFront(Canvas c, Size s) {
    final w = s.width, h = s.height;
    if (variant == SceneVariant.menu) {
      _hills(c, s, h * 0.78, theme.hillNear, 2, 0.035);
      _flowers(c, s, h * 0.8, h * 0.95, 26, 11);
      _cloudBank(c, s, h * 0.93);
    } else {
      // Grassy mound the jar sits on.
      final top = h * 0.84;
      final mound = Path()
        ..moveTo(0, h)
        ..lineTo(0, top + h * 0.03)
        ..quadraticBezierTo(w * 0.5, top - h * 0.03, w, top + h * 0.03)
        ..lineTo(w, h)
        ..close();
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.hillNear, theme.grassDark],
      ).createShader(Rect.fromLTWH(0, top, w, h - top));
      c.drawPath(mound, _p);
      _p.shader = null;
      _flowers(c, s, top + h * 0.01, h * 0.99, 20, 7);
    }
  }

  void _hills(
    Canvas c,
    Size s,
    double top,
    Color color,
    int bumps,
    double amp,
  ) {
    final w = s.width, h = s.height;
    final path = Path()..moveTo(0, h);
    path.lineTo(0, top);
    final seg = w / bumps;
    for (var i = 0; i < bumps; i++) {
      final x0 = i * seg;
      path.quadraticBezierTo(
        x0 + seg / 2,
        top - h * amp * (i.isEven ? 1.3 : 0.7),
        x0 + seg,
        top,
      );
    }
    path
      ..lineTo(w, h)
      ..close();
    _p.color = color;
    c.drawPath(path, _p);
  }

  void _flowers(Canvas c, Size s, double y0, double y1, int n, int seed) {
    final rnd = math.Random(seed);
    const colors = [
      Color(0xFFFF9EC4),
      Color(0xFFFFFFFF),
      Color(0xFFFFD86B),
      Color(0xFFC6A8FF),
      Color(0xFFFF7FA8),
    ];
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = y0 + rnd.nextDouble() * (y1 - y0);
      final r = s.width * (0.008 + rnd.nextDouble() * 0.009);
      _flower(c, Offset(x, y), r, colors[i % colors.length]);
    }
  }

  static void _flower(Canvas c, Offset at, double r, Color petal) {
    _p.color = petal;
    for (var k = 0; k < 5; k++) {
      final a = k * math.pi * 2 / 5 - math.pi / 2;
      c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * r, r * 0.85, _p);
    }
    _p.color = const Color(0xFFFFC94A);
    c.drawCircle(at, r * 0.7, _p);
  }

  void _cloudBank(Canvas c, Size s, double top) {
    final w = s.width;
    final rnd = math.Random(3);
    for (var i = 0; i < 9; i++) {
      final x = w * (i / 8) + (rnd.nextDouble() - 0.5) * w * 0.06;
      final r = w * (0.11 + rnd.nextDouble() * 0.06);
      _p.color = i.isEven ? AppColors.cloud : const Color(0xFFFFEEF5);
      c.drawCircle(Offset(x, top + r * 0.55), r, _p);
    }
  }

  void _castleIsland(Canvas c, Offset at, double size) {
    // Floating island.
    _p.color = const Color(0xFFB9E3B0);
    c.drawOval(
      Rect.fromCenter(
        center: at + Offset(0, size * 0.55),
        width: size * 1.5,
        height: size * 0.32,
      ),
      _p,
    );
    final rock = Path()
      ..moveTo(at.dx - size * 0.7, at.dy + size * 0.58)
      ..quadraticBezierTo(
        at.dx,
        at.dy + size * 1.35,
        at.dx + size * 0.7,
        at.dy + size * 0.58,
      )
      ..close();
    _p.color = const Color(0xFFD9B8E8);
    c.drawPath(rock, _p);

    // Castle: walls + three towers with cone roofs (soft lavender/pink).
    const wall = Color(0xFFF7EEFF);
    const roof = Color(0xFFB58CF0);
    _p.color = wall;
    c.drawRect(
      Rect.fromLTWH(
        at.dx - size * 0.35,
        at.dy + size * 0.1,
        size * 0.7,
        size * 0.4,
      ),
      _p,
    );
    for (final (dx, tw, th) in [
      (-0.35, 0.2, 0.6),
      (0.0, 0.24, 0.85),
      (0.35, 0.2, 0.6),
    ]) {
      final x = at.dx + size * dx;
      final top = at.dy + size * (0.5 - th);
      _p.color = wall;
      c.drawRect(
        Rect.fromLTWH(x - size * tw / 2, top, size * tw, size * th),
        _p,
      );
      final cone = Path()
        ..moveTo(x - size * tw * 0.65, top)
        ..lineTo(x, top - size * 0.28)
        ..lineTo(x + size * tw * 0.65, top)
        ..close();
      _p.color = roof;
      c.drawPath(cone, _p);
      _p.color = const Color(0xFFFF8FB8);
      c.drawRect(
        Rect.fromLTWH(x, top - size * 0.4, size * 0.012 + 1, size * 0.12),
        _p,
      );
    }
    _p.color = const Color(0xFFC9B2EC);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          at.dx - size * 0.06,
          at.dy + size * 0.32,
          size * 0.12,
          size * 0.18,
        ),
        Radius.circular(size * 0.06),
      ),
      _p,
    );
  }

  // ---------------------------------------------------------------------------
  // Moving layer: clouds drifting, balloons bobbing.

  /// Tiny four-point stars scattered across the upper sky.
  void _stars(Canvas c, Size s) {
    final rnd = math.Random(42);
    _p.color = const Color(0xCCFFFFFF);
    for (var i = 0; i < 28; i++) {
      final at = Offset(
        rnd.nextDouble() * s.width,
        rnd.nextDouble() * s.height * 0.55,
      );
      final r = s.width * (0.004 + rnd.nextDouble() * 0.006);
      final star = Path()
        ..moveTo(at.dx, at.dy - r * 2)
        ..quadraticBezierTo(at.dx, at.dy, at.dx + r * 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r * 2)
        ..quadraticBezierTo(at.dx, at.dy, at.dx - r * 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r * 2);
      c.drawPath(star, _p);
    }
  }

  void _drawMoving(Canvas c, Size s, double t) {
    final w = s.width, h = s.height;
    const clouds = [
      // (y fraction, size fraction, speed px/s, phase)
      (0.06, 0.2, 6.0, 0.1),
      (0.16, 0.14, 4.0, 0.55),
      (0.3, 0.17, 5.0, 0.8),
      (0.45, 0.12, 3.0, 0.3),
    ];
    for (final (fy, fs, speed, phase) in clouds) {
      final cw = w * fs * 2.2;
      final span = w + cw;
      final x = ((phase * span + t * speed) % span) - cw / 2;
      _cloud(c, Offset(x, h * fy), w * fs);
    }

    _balloon(
      c,
      Offset(w * 0.78, h * 0.12 + math.sin(t * 0.8) * 6),
      w * 0.045,
      const Color(0xFFFF9EC4),
      const Color(0xFFFFD86B),
    );
    if (variant == SceneVariant.menu) {
      _balloon(
        c,
        Offset(w * 0.62, h * 0.27 + math.sin(t * 0.6 + 2) * 5),
        w * 0.03,
        const Color(0xFFC6A8FF),
        const Color(0xFF9FD8FF),
      );
    }
  }

  static void _cloud(Canvas c, Offset at, double r) {
    _p.color = AppColors.cloudShade.withValues(alpha: 0.7);
    for (final (dx, dy, rr) in const [
      (-0.55, 0.2, 0.5),
      (0.0, 0.08, 0.68),
      (0.6, 0.22, 0.48),
    ]) {
      c.drawCircle(at + Offset(dx * r, dy * r + r * 0.08), rr * r, _p);
    }
    _p.color = AppColors.cloud;
    for (final (dx, dy, rr) in const [
      (-0.55, 0.15, 0.5),
      (0.0, 0.0, 0.68),
      (0.6, 0.18, 0.48),
      (-0.2, 0.3, 0.45),
      (0.3, 0.32, 0.42),
    ]) {
      c.drawCircle(at + Offset(dx * r, dy * r), rr * r, _p);
    }
  }

  static void _balloon(Canvas c, Offset at, double r, Color a, Color b) {
    // Envelope with two-color stripes.
    final env = Rect.fromCenter(center: at, width: r * 2, height: r * 2.3);
    c.save();
    c.clipPath(Path()..addOval(env));
    _p.color = a;
    c.drawRect(env, _p);
    _p.color = b;
    for (final dx in const [-0.55, 0.25]) {
      c.drawRect(
        Rect.fromLTWH(at.dx + dx * r, env.top, r * 0.3, env.height),
        _p,
      );
    }
    c.restore();
    _p.color = const Color(0x55FFFFFF);
    c.drawOval(
      Rect.fromCenter(
        center: at + Offset(-r * 0.4, -r * 0.5),
        width: r * 0.5,
        height: r * 0.7,
      ),
      _p,
    );
    // Ropes + basket.
    _p
      ..color = const Color(0xFF9A6B4A)
      ..strokeWidth = math.max(1, r * 0.06);
    c.drawLine(
      at + Offset(-r * 0.5, r * 1.0),
      at + Offset(-r * 0.3, r * 1.5),
      _p,
    );
    c.drawLine(
      at + Offset(r * 0.5, r * 1.0),
      at + Offset(r * 0.3, r * 1.5),
      _p,
    );
    _p.color = const Color(0xFFC98E52);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx - r * 0.35, at.dy + r * 1.5, r * 0.7, r * 0.45),
        Radius.circular(r * 0.1),
      ),
      _p,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.variant != variant || old.theme != theme;
}
