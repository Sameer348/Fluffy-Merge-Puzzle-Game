import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/motion.dart';

/// Vertical meter on the jar's left wall: fills green → yellow → red as the
/// pile approaches the danger line. A bigger fill (not just a redder colour)
/// carries the meaning.
class DangerMeter extends StatelessWidget {
  const DangerMeter({super.key, required this.danger, required this.width});

  final ValueNotifier<double> danger;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: danger,
      builder: (context, d, _) => Semantics(
        container: true,
        label: 'Jar fullness',
        value: '${(d * 100).round()}%',
        child: Container(
          width: width,
          padding: EdgeInsets.all(width * 0.18),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(width),
            border: Border.all(color: AppColors.white, width: 1.5),
          ),
          // Fixed gradient along the whole bar (green bottom → red top); a
          // cover slides down from the top to reveal the current fill.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.candyGreen,
                        AppColors.candyYellow,
                        AppColors.danger,
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    widthFactor: 1,
                    // Always leave a sliver so the meter reads as "there".
                    heightFactor: 1 - (0.1 + 0.9 * d),
                    child: const ColoredBox(color: Color(0xFFF7F1FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-drop coaching: a tilted paper tag "Drag to aim / Release to drop"
/// and a pointing hand that sways left and right over the jar. Hidden for
/// good once the first creature is dropped.
class AimHint extends StatefulWidget {
  const AimHint({super.key, required this.drops, required this.scale});

  final ValueNotifier<int> drops;
  final double scale;

  @override
  State<AimHint> createState() => _AimHintState();
}

class _AimHintState extends State<AimHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: widget.drops,
        builder: (context, drops, child) => AnimatedOpacity(
          opacity: drops == 0 ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: child,
        ),
        child: Stack(
          children: [
            Positioned(
              left: s * 16,
              top: s * 70,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: s * 12,
                    vertical: s * 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(s * 10),
                    border: Border.all(color: AppColors.panelBorder, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22975A2A),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Drag to aim\nRelease to drop',
                    textAlign: TextAlign.center,
                    style: AppText.display(s * 14, color: AppColors.woodDark),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_c.value);
                return Align(
                  alignment: Alignment(-0.45 + 0.9 * t, -0.86),
                  child: Transform.rotate(
                    angle: -0.3 + 0.2 * math.sin(t * math.pi),
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.touch_app_rounded,
                size: s * 46,
                color: AppColors.white,
                shadows: const [
                  Shadow(
                    color: Color(0x664A3F45),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
