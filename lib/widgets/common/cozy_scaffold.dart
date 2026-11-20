import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../buttons/pressable_scale.dart';
import '../scene/scene_background.dart';
import 'wood_sign.dart';

/// Standard screen shell: storybook scene background (or a custom one),
/// safe area, optional wooden-sign title with a round back button, and a
/// max content width on tablets.
class CozyScaffold extends StatelessWidget {
  const CozyScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = true,
    this.constrainWidth = true,
    this.background,
  });

  final Widget child;
  final String? title;
  final bool showBack;
  final bool constrainWidth;

  /// Full-bleed layer behind the content. Defaults to the storybook scene.
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    Widget body = child;
    if (constrainWidth) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: child,
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            Positioned.fill(child: background ?? const SceneBackground()),
            SafeArea(
              child: Column(
                children: [
                  if (title != null || canPop)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.sm,
                        AppSizes.lg,
                        AppSizes.sm,
                      ),
                      child: SizedBox(
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Title is inset so it can never cover the back
                            // button; the button is painted last so it always
                            // wins hit-testing.
                            if (title != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.minTap + AppSizes.sm,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: WoodSign(text: title!, fontSize: 24),
                                ),
                              ),
                            if (canPop)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: RoundIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  semanticLabel: 'Back',
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small white circular icon button used for back / pause / settings.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = AppSizes.minTap,
    this.color = AppColors.textDark,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.soft,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
