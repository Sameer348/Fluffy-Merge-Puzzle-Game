import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/motion.dart';
import '../buttons/soft_button.dart';
import '../common/wood_sign.dart';

/// Storybook confirm dialog: wooden sign title, cream panel, optional
/// preview (e.g. the creature about to be popped), and two candy buttons.
///
/// Returns true only when the player taps the confirm button; tapping
/// outside, back, or Cancel all return false.
Future<bool> showCozyConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  Widget? preview,
  CandyColor confirmColor = CandyColor.pink,
}) async {
  final reduce = reduceMotion(context);
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x664A3F45),
    transitionDuration: Duration(milliseconds: reduce ? 120 : 260),
    pageBuilder: (context, _, _) => _CozyDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      preview: preview,
      confirmColor: confirmColor,
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: reduce
            ? child
            : ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(curved),
                child: child,
              ),
      );
    },
  );
  return result ?? false;
}

class _CozyDialog extends StatelessWidget {
  const _CozyDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.preview,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Widget? preview;
  final CandyColor confirmColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
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
                      if (preview != null) ...[
                        preview!,
                        const SizedBox(height: 10),
                      ],
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppText.body(17, color: AppColors.woodDark),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SoftButton(
                              label: cancelLabel,
                              candy: CandyColor.blue,
                              height: 52,
                              fontSize: 19,
                              onTap: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SoftButton(
                              label: confirmLabel,
                              candy: confirmColor,
                              height: 52,
                              fontSize: 19,
                              onTap: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                WoodSign(text: title, fontSize: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
