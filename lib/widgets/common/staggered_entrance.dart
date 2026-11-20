import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/utils/motion.dart';

/// Fades, lifts and scales (0.96 → 1.0) a child in after `index × 70 ms`.
/// Use increasing indexes down a screen for a staggered menu entrance.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 60),
  });

  final int index;
  final Widget child;
  final Duration baseDelay;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: AppCurves.soft,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.96,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: AppCurves.bouncy));
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(_fade);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      _timer = Timer(
        widget.baseDelay + AppDurations.stagger * widget.index,
        () => mounted ? _c.forward() : null,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
