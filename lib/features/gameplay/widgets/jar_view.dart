import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/utils/motion.dart';
import '../../../game/fluffy_game.dart';
import '../../../game/physics/physics_config.dart';
import 'jar_overlays.dart';
import 'next_preview.dart';

/// Thickness of the jar rim drawn *outside* the play area, so the playable
/// rect keeps the exact world aspect ratio.
const double kJarRim = 6;

/// The jar: decorative frame, background decor (glass highlight + danger
/// line), the Flame game clipped to the rounded interior, and touch input.
///
/// Input uses a raw [Listener] (no gesture arena delay): finger down/move
/// aims, finger up drops. While [onPick] is set (POP/GROW targeting), a
/// tap reports its position instead and nothing is aimed or dropped.
///
/// When SHAKE fires, the whole jar wobbles side to side (skipped with
/// reduce motion; the physics shake still happens).
class JarView extends StatefulWidget {
  const JarView({super.key, required this.game, this.onPick});

  final FluffyGame game;

  /// Receives tap positions in GameWidget pixels while picking a target.
  final void Function(Vector2 px)? onPick;

  @override
  State<JarView> createState() => _JarViewState();
}

class _JarViewState extends State<JarView> with SingleTickerProviderStateMixin {
  int? _pointer;
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    widget.game.powerUps.shakes.addListener(_onShake);
  }

  void _onShake() {
    if (!reduceMotion(context)) _wobble.forward(from: 0);
  }

  @override
  void dispose() {
    widget.game.powerUps.shakes.removeListener(_onShake);
    _wobble.dispose();
    super.dispose();
  }

  Vector2 _px(PointerEvent e) =>
      Vector2(e.localPosition.dx - kJarRim, e.localPosition.dy - kJarRim);

  void _down(PointerDownEvent e) {
    if (_pointer != null) return; // one finger at a time
    _pointer = e.pointer;
    if (widget.onPick == null) widget.game.aimAtPixel(_px(e).x);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (widget.onPick == null) widget.game.aimAtPixel(_px(e).x);
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final pick = widget.onPick;
    if (pick != null) {
      pick(_px(e));
      return;
    }
    widget.game.aimAtPixel(_px(e).x);
    widget.game.drop();
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wobble,
      builder: (context, child) {
        final t = _wobble.value;
        // Decaying side-to-side wobble with a little tilt.
        final w = t == 0 ? 0.0 : math.sin(t * math.pi * 6) * (1 - t);
        return Transform.translate(
          offset: Offset(w * 10, 0),
          child: Transform.rotate(angle: w * 0.02, child: child),
        );
      },
      child: _buildJar(context),
    );
  }

  Widget _buildJar(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Jar. Drag to aim, release to drop.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Interior corners match the physics walls' corner radius, so
            // the curve you see is the curve creatures roll against.
            final inner = constraints.maxWidth - kJarRim * 2;
            final innerRadius =
                PhysicsConfig.cornerRadius * inner / GameConstants.worldWidth;
            final unit = inner / 360; // overlay scale relative to a phone jar
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Glass jar: frosted, see-through interior and a bright rim.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        innerRadius + kJarRim,
                      ),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.95),
                        width: kJarRim,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // Frosted, warm glass: enough tint that creatures
                        // read clearly over the sky behind the jar.
                        colors: [
                          const Color(0xFFFFFBF6).withValues(alpha: 0.78),
                          const Color(0xFFFFEFE4).withValues(alpha: 0.9),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x336E3AA7),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(innerRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const RepaintBoundary(
                            child: CustomPaint(painter: _JarDecorPainter()),
                          ),
                          GameWidget<FluffyGame>(game: widget.game),
                          // Repeats the jar's own label; hide from readers.
                          ExcludeSemantics(
                            child: AimHint(
                              drops: widget.game.drops,
                              scale: unit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Fullness meter on the left wall, below the danger line.
                Positioned(
                  left: kJarRim + inner * 0.03,
                  top: constraints.maxHeight * 0.22,
                  height: constraints.maxHeight * 0.4,
                  child: IgnorePointer(
                    child: DangerMeter(
                      danger: widget.game.dangerLevel,
                      width: 12 * unit,
                    ),
                  ),
                ),
                // NEXT bubble tucked into the top-right corner.
                Positioned(
                  right: kJarRim + 6 * unit,
                  top: kJarRim + 6 * unit,
                  child: IgnorePointer(
                    child: NextPreview(
                      level: widget.game.nextLevel,
                      size: 40 * unit,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JarDecorPainter extends CustomPainter {
  const _JarDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Glass reflections: a tall soft streak on the right, a short one left.
    final p = Paint()..color = AppColors.white.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.9,
          size.height * 0.16,
          size.width * 0.025,
          size.height * 0.5,
        ),
        const Radius.circular(20),
      ),
      p,
    );
    p.color = AppColors.white.withValues(alpha: 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.86,
          size.height * 0.2,
          size.width * 0.012,
          size.height * 0.18,
        ),
        const Radius.circular(20),
      ),
      p,
    );
    // The danger line is drawn by the game (DangerLineComponent) so it
    // can pulse with the danger level.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
