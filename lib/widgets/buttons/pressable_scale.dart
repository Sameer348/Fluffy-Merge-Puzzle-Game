import 'package:flutter/widgets.dart';

import '../../core/constants/app_sizes.dart';

/// Wraps any widget with the standard "squishy" press feedback
/// (scale 1.0 → 0.94 while pressed). Used by every tappable surface.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.94,
    this.semanticLabel,
    this.dimWhenDisabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;

  /// Fade to 50% when [onTap] is null.
  final bool dimWhenDisabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      // With an explicit label, hide the children's text: decorative
      // duplicates (outlined text is drawn twice) would otherwise be read
      // out as "Play, Play".
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: enabled || !widget.dimWhenDisabled ? 1 : 0.5,
            duration: AppDurations.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
