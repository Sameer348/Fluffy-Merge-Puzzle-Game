import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../game/models/creature_spec.dart';
import '../../../widgets/creature/creature_view.dart';

/// "NEXT" bubble in the HUD. Only this widget rebuilds when the queue
/// changes; the new creature pops in with a bouncy scale.
class NextPreview extends StatelessWidget {
  const NextPreview({super.key, required this.level, required this.size});

  final ValueNotifier<int> level;
  final double size;

  @override
  Widget build(BuildContext context) {
    // One semantic node, "Next: <name>"; the visible "NEXT" text and the
    // creature image are decorative duplicates.
    return ValueListenableBuilder<int>(
      valueListenable: level,
      builder: (context, lvl, child) => Semantics(
        container: true,
        label: 'Next: ${CreatureCatalog.byLevel(lvl).name}',
        excludeSemantics: true,
        child: child,
      ),
      child: _bubble(),
    );
  }

  Widget _bubble() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        size * 0.22,
        size * 0.08,
        size * 0.12,
        size * 0.08,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NEXT',
            style: AppText.body(
              size * 0.26,
              color: AppColors.softBrown,
              weight: FontWeight.w900,
            ),
          ),
          SizedBox(width: size * 0.1),
          SizedBox.square(
            dimension: size * 0.84,
            child: ValueListenableBuilder<int>(
              valueListenable: level,
              builder: (context, lvl, _) {
                final spec = CreatureCatalog.byLevel(lvl);
                return AnimatedSwitcher(
                  duration: AppDurations.normal,
                  switchInCurve: AppCurves.bouncy,
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: CreatureView(
                    key: ValueKey(lvl),
                    spec: spec,
                    // Scale by level so size differences read at a glance.
                    size: size * (0.5 + 0.07 * lvl).clamp(0.5, 0.84),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
