import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// Shapes a particle can have.
enum ParticleShape { circle, star, sparkle }

/// All merge particles in one component, backed by fixed-size typed arrays.
///
/// * Particles live in preallocated typed arrays: firing a burst allocates
///   nothing, and dead particles are swap-removed. (Drawing creates one
///   short-lived Color per visible particle, since Paint only takes Color
///   objects; that's the only per-frame garbage.)
/// * When the pool is full the oldest particles are recycled, so a huge
///   chain can never grow memory or tank the frame rate.
/// * Expanding "shockwave" rings use a second, smaller pool.
///
/// Coordinates are world units (jar meters), so bursts stay attached to the
/// jar on every screen size.
class ParticleSystem extends Component {
  ParticleSystem({
    this.capacity = 240,
    this.ringCapacity = 12,
    this.reduceMotion = false,
    int seed = 0,
  }) : _rng = math.Random(seed),
       super(priority: 50) {
    _x = Float32List(capacity);
    _y = Float32List(capacity);
    _vx = Float32List(capacity);
    _vy = Float32List(capacity);
    _age = Float32List(capacity);
    _life = Float32List(capacity);
    _size = Float32List(capacity);
    _rot = Float32List(capacity);
    _spin = Float32List(capacity);
    _shape = Uint8List(capacity);
    _color = Uint32List(capacity);
    _born = Uint32List(capacity);

    _rx = Float32List(ringCapacity);
    _ry = Float32List(ringCapacity);
    _rAge = Float32List(ringCapacity);
    _rLife = Float32List(ringCapacity);
    _rMax = Float32List(ringCapacity);
    _rColor = Uint32List(ringCapacity);
  }

  final int capacity;
  final int ringCapacity;
  final bool reduceMotion;
  final math.Random _rng;

  late final Float32List _x, _y, _vx, _vy, _age, _life, _size, _rot, _spin;
  late final Uint8List _shape;
  late final Uint32List _color, _born;
  int _count = 0;
  int _serial = 0;

  late final Float32List _rx, _ry, _rAge, _rLife, _rMax;
  late final Uint32List _rColor;
  int _rings = 0;

  int get activeCount => _count;
  int get activeRings => _rings;

  /// Gentle downward pull and air drag (world units / s²).
  static const double _gravity = 6;
  static const double _drag = 2.2;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _ringPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Path _star = _makeStar();
  static final Path _sparkle = _makeSparkle();

  /// Emits [count] particles at [at] using [colors].
  ///
  /// [speed] is the typical launch speed (m/s), [size] the typical particle
  /// radius (m). Reduced motion emits a third as many, slower and smaller.
  void burst(
    Vector2 at, {
    required int count,
    required List<Color> colors,
    double speed = 4,
    double size = 0.12,
    double life = 0.7,
  }) {
    if (colors.isEmpty || count <= 0) return;
    var n = count;
    var spd = speed;
    if (reduceMotion) {
      n = math.max(1, count ~/ 3);
      spd = speed * 0.35;
    }
    for (var k = 0; k < n; k++) {
      final i = _slot();
      final a = _rng.nextDouble() * math.pi * 2;
      final s = spd * (0.45 + _rng.nextDouble() * 0.75);
      _x[i] = at.x;
      _y[i] = at.y;
      _vx[i] = math.cos(a) * s;
      _vy[i] = math.sin(a) * s - spd * 0.35; // slight upward bias
      _age[i] = 0;
      _life[i] = life * (0.7 + _rng.nextDouble() * 0.6);
      _size[i] = size * (0.6 + _rng.nextDouble() * 0.8);
      _rot[i] = _rng.nextDouble() * math.pi;
      _spin[i] = (_rng.nextDouble() - 0.5) * 8;
      final r = _rng.nextDouble();
      _shape[i] = r < 0.45
          ? ParticleShape.circle.index
          : (r < 0.75 ? ParticleShape.star.index : ParticleShape.sparkle.index);
      _color[i] = colors[k % colors.length].toARGB32();
      _born[i] = _serial++;
    }
  }

  /// Adds an expanding soft ring at [at] that grows to [radius].
  void ring(Vector2 at, {required double radius, required Color color}) {
    if (reduceMotion) return;
    int i;
    if (_rings < ringCapacity) {
      i = _rings++;
    } else {
      // Recycle the oldest ring.
      i = 0;
      for (var k = 1; k < _rings; k++) {
        if (_rAge[k] > _rAge[i]) i = k;
      }
    }
    _rx[i] = at.x;
    _ry[i] = at.y;
    _rAge[i] = 0;
    _rLife[i] = 0.45;
    _rMax[i] = radius;
    _rColor[i] = color.toARGB32();
  }

  /// Free slot, or the oldest particle if the pool is full.
  int _slot() {
    if (_count < capacity) return _count++;
    var oldest = 0;
    for (var k = 1; k < _count; k++) {
      if (_born[k] < _born[oldest]) oldest = k;
    }
    return oldest;
  }

  void _copy(int from, int to) {
    _x[to] = _x[from];
    _y[to] = _y[from];
    _vx[to] = _vx[from];
    _vy[to] = _vy[from];
    _age[to] = _age[from];
    _life[to] = _life[from];
    _size[to] = _size[from];
    _rot[to] = _rot[from];
    _spin[to] = _spin[from];
    _shape[to] = _shape[from];
    _color[to] = _color[from];
    _born[to] = _born[from];
  }

  void clear() {
    _count = 0;
    _rings = 0;
  }

  @override
  void update(double dt) {
    final damp = math.exp(-_drag * dt);
    var i = 0;
    while (i < _count) {
      final age = _age[i] + dt;
      if (age >= _life[i]) {
        _count--;
        if (i != _count) _copy(_count, i);
        continue; // re-check the particle moved into slot i
      }
      _age[i] = age;
      _vx[i] *= damp;
      _vy[i] = _vy[i] * damp + _gravity * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _rot[i] += _spin[i] * dt;
      i++;
    }

    var r = 0;
    while (r < _rings) {
      _rAge[r] += dt;
      if (_rAge[r] >= _rLife[r]) {
        _rings--;
        if (r != _rings) {
          _rx[r] = _rx[_rings];
          _ry[r] = _ry[_rings];
          _rAge[r] = _rAge[_rings];
          _rLife[r] = _rLife[_rings];
          _rMax[r] = _rMax[_rings];
          _rColor[r] = _rColor[_rings];
        }
        continue;
      }
      r++;
    }
  }

  @override
  void render(Canvas canvas) {
    for (var r = 0; r < _rings; r++) {
      final t = _rAge[r] / _rLife[r];
      final e = 1 - (1 - t) * (1 - t); // ease-out
      final rad = _rMax[r] * (0.35 + 0.65 * e);
      _ringPaint
        ..strokeWidth = _rMax[r] * 0.12 * (1 - t)
        ..color = Color(_rColor[r]).withValues(alpha: 0.55 * (1 - t));
      canvas.drawCircle(Offset(_rx[r], _ry[r]), rad, _ringPaint);
    }

    for (var i = 0; i < _count; i++) {
      final t = _age[i] / _life[i];
      // Pop in quickly, then shrink and fade.
      final grow = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85 * 0.6;
      final s = _size[i] * grow;
      final alpha = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
      final argb = _color[i];
      final a = ((argb >>> 24) * alpha).round().clamp(0, 255);
      _fill.color = Color((a << 24) | (argb & 0x00FFFFFF));
      final shape = _shape[i];
      if (shape == ParticleShape.circle.index) {
        canvas.drawCircle(Offset(_x[i], _y[i]), s, _fill);
      } else {
        canvas.save();
        canvas.translate(_x[i], _y[i]);
        canvas.rotate(_rot[i]);
        canvas.scale(s);
        canvas.drawPath(
          shape == ParticleShape.star.index ? _star : _sparkle,
          _fill,
        );
        canvas.restore();
      }
    }
  }

  /// Unit 5-point star (outer radius 1.3 so it reads the same size as a dot).
  static Path _makeStar() {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 1.3 : 0.55;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = math.cos(a) * r, y = math.sin(a) * r;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  /// Unit 4-point "twinkle".
  static Path _makeSparkle() {
    const s = 1.5;
    return Path()
      ..moveTo(0, -s)
      ..quadraticBezierTo(0, 0, s, 0)
      ..quadraticBezierTo(0, 0, 0, s)
      ..quadraticBezierTo(0, 0, -s, 0)
      ..quadraticBezierTo(0, 0, 0, -s)
      ..close();
  }
}
