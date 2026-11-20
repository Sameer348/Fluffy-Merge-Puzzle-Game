import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/motion.dart';

/// Very subtle ambient background: soft pastel dots and tiny sparkles that
/// drift upward. Positions are a pure function of time (no per-frame
/// allocation, no state per particle), and the ticker pauses automatically
/// when the route is covered (TickerMode) or reduce-motion is on.
class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key, this.count = 16});

  final int count;

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMicroseconds / 1e6,
  );
  late final List<_Particle> _particles = _seed(widget.count);

  static List<_Particle> _seed(int n) {
    final rnd = math.Random(7);
    const colors = [
      AppColors.coral,
      AppColors.mint,
      AppColors.sunshine,
      AppColors.lavender,
      AppColors.sky,
    ];
    return List.generate(n, (i) {
      return _Particle(
        x: rnd.nextDouble(),
        offset: rnd.nextDouble(),
        speed: 0.012 + rnd.nextDouble() * 0.02,
        size: 3 + rnd.nextDouble() * 6,
        sway: 6 + rnd.nextDouble() * 14,
        phase: rnd.nextDouble() * math.pi * 2,
        sparkle: i % 4 == 0,
        color: colors[i % colors.length].withValues(
          alpha: 0.22 + rnd.nextDouble() * 0.2,
        ),
      );
    });
  }

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
          painter: _ParticlesPainter(_time, _particles),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.sway,
    required this.phase,
    required this.sparkle,
    required this.color,
  });

  final double x, offset, speed, size, sway, phase;
  final bool sparkle;
  final Color color;
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter(this.time, this.particles) : super(repaint: time);

  final ValueNotifier<double> time;
  final List<_Particle> particles;
  final Paint _paint = Paint();
  final Path _spark = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final p in particles) {
      // Travel 0 → 1.2 of the height, wrapping, starting below the screen.
      final progress = (p.offset + t * p.speed) % 1.2;
      final y = size.height * (1.1 - progress);
      final x = p.x * size.width + math.sin(t * 0.6 + p.phase) * p.sway;
      // Fade in at the bottom and out near the top.
      final fade = (math.min(progress, 1.2 - progress) * 4).clamp(0.0, 1.0);
      _paint.color = p.color.withValues(alpha: p.color.a * fade);
      if (p.sparkle) {
        final s = p.size * 0.9;
        _spark
          ..reset()
          ..moveTo(x, y - s)
          ..quadraticBezierTo(x, y, x + s, y)
          ..quadraticBezierTo(x, y, x, y + s)
          ..quadraticBezierTo(x, y, x - s, y)
          ..quadraticBezierTo(x, y, x, y - s);
        canvas.drawPath(_spark, _paint);
      } else {
        canvas.drawCircle(Offset(x, y), p.size / 2, _paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.particles != particles;
}
