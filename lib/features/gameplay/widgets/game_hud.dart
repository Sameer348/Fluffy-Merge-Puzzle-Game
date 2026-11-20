import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../game/fluffy_game.dart';
import '../../../widgets/buttons/pressable_scale.dart';
import '../../../widgets/common/cozy_scaffold.dart';
import '../../../widgets/score/bounce_on_change.dart';
import '../../../widgets/score/stat_chip.dart';

/// Top bar: pause + score (left) · level badge (centre) · coins with a
/// "+" shortcut (right). The sides share the leftover width and shrink big
/// numbers to fit; only the chips listening to a value rebuild.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.r,
    required this.game,
    required this.wallet,
    required this.onPause,
    required this.onAddCoins,
  });

  final Responsive r;
  final FluffyGame game;

  /// Coins saved before this run; the chip shows wallet + earned.
  final int wallet;
  final VoidCallback onPause;
  final VoidCallback onAddCoins;

  @override
  Widget build(BuildContext context) {
    final h = r.s(40);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(12)),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.pause_rounded,
            semanticLabel: 'Pause',
            size: r.s(42),
            color: AppColors.candyPurple,
            onTap: onPause,
          ),
          SizedBox(width: r.s(6)),
          Expanded(
            child: _Fit(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<int>(
                valueListenable: game.scoring.score,
                builder: (_, score, _) => StatChip(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.sunshineDeep,
                  value: score,
                  semanticLabel: 'Score',
                  height: h,
                ),
              ),
            ),
          ),
          SizedBox(width: r.s(6)),
          ValueListenableBuilder<int>(
            valueListenable: game.highestLevel,
            builder: (_, lvl, _) => LevelBadge(level: lvl, height: r.s(46)),
          ),
          SizedBox(width: r.s(6)),
          Expanded(
            child: _Fit(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.scoring.coins,
                    builder: (_, earned, _) => BounceOnChange(
                      value: earned,
                      child: StatChip(
                        icon: Icons.monetization_on_rounded,
                        iconColor: AppColors.sunshineDeep,
                        value: wallet + earned,
                        semanticLabel: 'Coins',
                        height: h,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(-h * 0.35, 0),
                    child: _PlusButton(size: h * 0.72, onTap: onAddCoins),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Purple "Lv. N" badge with a green progress bar: the highest creature
/// reached this run, out of 12.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, required this.height});

  final int level;
  final double height;

  @override
  Widget build(BuildContext context) {
    final progress = level / GameConstants.maxLevel;
    return Semantics(
      label: 'Highest creature: level $level of ${GameConstants.maxLevel}',
      excludeSemantics: true,
      child: SizedBox(
        width: height * 1.9,
        height: height,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Progress track.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.3,
              child: Container(
                padding: EdgeInsets.all(height * 0.04),
                decoration: BoxDecoration(
                  color: AppColors.candyPurpleLip,
                  borderRadius: BorderRadius.circular(height),
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    widthFactor: progress.clamp(0.08, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.candyGreenTop,
                            AppColors.candyGreen,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // "Lv. N" pill.
            Container(
              height: height * 0.66,
              padding: EdgeInsets.symmetric(horizontal: height * 0.28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                border: Border.all(color: AppColors.white, width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.candyPurpleTop, AppColors.candyPurple],
                ),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                child: Text(
                  'Lv. $level',
                  style: AppText.display(
                    height * 0.36,
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Get more coins',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.candyGreenTop, AppColors.candyGreen],
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          color: AppColors.white,
          size: size * 0.75,
        ),
      ),
    );
  }
}

/// Scales its child down (never up) to fit, keeping the given alignment.
class _Fit extends StatelessWidget {
  const _Fit({required this.child, required this.alignment});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child),
  );
}
