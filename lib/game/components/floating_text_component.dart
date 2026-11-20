import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';

/// "MERGE!" / "COMBO x2!" style popup with a smaller "+30" line under it.
///
/// Lives in screen space (added to the camera viewport) so text renders at
/// real pixel sizes, crisp on every device. Pops in, rises, fades out, then
/// removes itself. Text is laid out once in [onLoad]; frames only translate,
/// scale and fade.
class FloatingTextComponent extends PositionComponent {
  FloatingTextComponent({
    required this.label,
    required this.color,
    required this.fontSize,
    required Vector2 position,
    this.sub,
    this.reduceMotion = false,
    this.lifetime = 1.0,
  }) : super(position: position, anchor: Anchor.center, priority: 100);

  final String label;
  final String? sub;
  final Color color;
  final double fontSize;
  final bool reduceMotion;
  final double lifetime;

  double _age = 0;
  double get age => _age;

  late final TextPainter _labelFill, _labelStroke;
  TextPainter? _subFill, _subStroke;
  final Paint _layerPaint = Paint();

  static TextPainter _paint(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  Future<void> onLoad() async {
    final base = AppText.display(fontSize)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: fontSize * 0.02);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fontSize * 0.22
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.white;
    _labelStroke = _paint(label, base.copyWith(foreground: stroke));
    _labelFill = _paint(label, base.copyWith(color: color));

    if (sub != null) {
      final subStyle = base.copyWith(fontSize: fontSize * 0.68);
      _subStroke = _paint(
        sub!,
        subStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.white,
        ),
      );
      _subFill = _paint(sub!, subStyle.copyWith(color: AppColors.textDark));
    }
    final w = math.max(_labelFill.width, _subFill?.width ?? 0) + fontSize * 0.4;
    final h = _labelFill.height + (_subFill?.height ?? 0);
    size = Vector2(w, h);
  }

  /// Skips ahead to the fade-out so a newer popup nearby is readable.
  void fadeOutSoon() {
    final fadeStart = lifetime * 0.6;
    if (_age < fadeStart) _age = fadeStart;
  }

  /// Width once laid out (used to keep the popup inside the jar).
  double get textWidth => size.x;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0.0, 1.0);
    // Fade out over the last 40%.
    final alpha = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    if (alpha <= 0) return;

    var scale = 1.0;
    var rise = 0.0;
    if (!reduceMotion) {
      // Pop: 0.6 → 1.15 → 1.0 in the first 25%.
      if (t < 0.25) {
        final p = t / 0.25;
        scale = p < 0.6
            ? 0.6 + 0.55 * (p / 0.6)
            : 1.15 - 0.15 * ((p - 0.6) / 0.4);
      }
      rise = fontSize * 1.8 * (1 - math.pow(1 - t, 3));
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 - rise);
    canvas.scale(scale);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: size.x + fontSize,
      height: size.y + fontSize,
    );
    _layerPaint.color = Color.fromRGBO(0, 0, 0, alpha);
    canvas.saveLayer(bounds, _layerPaint);

    final top = -size.y / 2;
    final lx = -_labelFill.width / 2;
    _labelStroke.paint(canvas, Offset(lx, top));
    _labelFill.paint(canvas, Offset(lx, top));
    final sf = _subFill, ss = _subStroke;
    if (sf != null && ss != null) {
      final sy = top + _labelFill.height * 0.92;
      ss.paint(canvas, Offset(-sf.width / 2, sy));
      sf.paint(canvas, Offset(-sf.width / 2, sy));
    }
    canvas.restore(); // layer
    canvas.restore();
  }

  @override
  void onRemove() {
    if (isLoaded) {
      _labelFill.dispose();
      _labelStroke.dispose();
      _subFill?.dispose();
      _subStroke?.dispose();
    }
    super.onRemove();
  }
}
