import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/motion.dart';

/// "Too full! 3…2…1" pill shown while the jar is overflowing. Pulses (or
/// stays steady with reduce motion) and is announced to screen readers.
class OverflowWarning extends StatefulWidget {
  const OverflowWarning({
    super.key,
    required this.countdown,
    required this.scale,
  });

  final ValueNotifier<int?> countdown;
  final double scale;

  @override
  State<OverflowWarning> createState() => _OverflowWarningState();
}

class _OverflowWarningState extends State<OverflowWarning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return IgnorePointer(
      child: ValueListenableBuilder<int?>(
        valueListenable: widget.countdown,
        builder: (context, left, _) {
          final show = left != null && left > 0;
          return AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: show
                ? Semantics(
                    liveRegion: true,
                    label: 'Jar too full! $left',
                    excludeSemantics: true,
                    child: ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.08).animate(_pulse),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 * s,
                          vertical: 6 * s,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: AppColors.white,
                            width: 2.5,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFF8A8A), AppColors.danger],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55F26B6B),
                              blurRadius: 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.white,
                              size: 20 * s,
                            ),
                            SizedBox(width: 6 * s),
                            // Shrinks with large text instead of overflowing.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Too full!  $left',
                                  maxLines: 1,
                                  style: AppText.display(
                                    18 * s,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
