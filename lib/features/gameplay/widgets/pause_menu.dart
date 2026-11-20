import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/motion.dart';
import '../../../widgets/buttons/soft_button.dart';
import '../../../widgets/common/wood_sign.dart';

enum PauseChoice { resume, restart, home }

/// Storybook pause menu. Tapping outside or the system back button
/// resumes, so it's never a trap.
Future<PauseChoice> showPauseMenu(BuildContext context) async {
  final reduce = reduceMotion(context);
  final choice = await showGeneralDialog<PauseChoice>(
    context: context,
    barrierDismissible: true,
    // Not 'Resume': that would duplicate the button for screen readers.
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x664A3F45),
    transitionDuration: Duration(milliseconds: reduce ? 120 : 240),
    pageBuilder: (context, _, _) => const _PauseMenu(),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: anim,
      child: reduce
          ? child
          : ScaleTransition(
              scale: Tween(begin: 0.88, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
    ),
  );
  return choice ?? PauseChoice.resume;
}

class _PauseMenu extends StatelessWidget {
  const _PauseMenu();

  @override
  Widget build(BuildContext context) {
    void pick(PauseChoice c) => Navigator.of(context).pop(c);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 26),
                  padding: const EdgeInsets.fromLTRB(22, 44, 22, 22),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.panelBorder, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40975A2A),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SoftButton(
                        label: 'Resume',
                        icon: Icons.play_arrow_rounded,
                        candy: CandyColor.green,
                        height: 58,
                        fontSize: 23,
                        onTap: () => pick(PauseChoice.resume),
                      ),
                      const SizedBox(height: 12),
                      SoftButton(
                        label: 'Restart',
                        icon: Icons.refresh_rounded,
                        candy: CandyColor.blue,
                        height: 54,
                        fontSize: 21,
                        onTap: () => pick(PauseChoice.restart),
                      ),
                      const SizedBox(height: 12),
                      SoftButton(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        candy: CandyColor.pink,
                        height: 54,
                        fontSize: 21,
                        onTap: () => pick(PauseChoice.home),
                      ),
                    ],
                  ),
                ),
                const WoodSign(
                  text: 'Paused',
                  fontSize: 26,
                  icon: Icons.pause_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
