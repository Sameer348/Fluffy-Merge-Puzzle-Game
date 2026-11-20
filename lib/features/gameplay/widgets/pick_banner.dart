import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/buttons/pressable_scale.dart';

/// Purple pill shown while choosing a POP/GROW target, with a close
/// button to cancel.
class PickBanner extends StatelessWidget {
  const PickBanner({
    super.key,
    required this.text,
    required this.scale,
    required this.onCancel,
  });

  final String text;
  final double scale;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      liveRegion: true,
      label: text,
      child: Container(
        padding: EdgeInsets.fromLTRB(16 * s, 6 * s, 6 * s, 6 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: AppColors.white, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.candyPurpleTop, AppColors.candyPurple],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x445733AE),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, color: AppColors.white, size: 20 * s),
            SizedBox(width: 6 * s),
            // Shrinks on narrow jars / large text instead of overflowing.
            Flexible(
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: AppText.display(16 * s, color: AppColors.white),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10 * s),
            PressableScale(
              onTap: onCancel,
              semanticLabel: 'Cancel',
              child: Container(
                width: 30 * s,
                height: 30 * s,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.candyPurple,
                  size: 20 * s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
