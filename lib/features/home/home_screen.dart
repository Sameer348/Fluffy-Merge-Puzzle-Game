import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/buttons/tile_button.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/common/floating_particles.dart';
import '../../widgets/common/staggered_entrance.dart';
import '../../widgets/scene/scene_background.dart';
import '../../widgets/score/stat_chip.dart';
import '../../data/repositories/save_controller.dart';
import '../daily_challenge/daily_controller.dart';
import 'home_providers.dart';
import 'widgets/game_logo.dart';
import 'widgets/home_mascot.dart';

/// Storybook home: stats, the purple-and-gold logo, Fluffy peeking over a
/// grassy ledge (fills spare height, so it scales from small phones to
/// tablets), a big glossy Play button overlapping the ledge, and cream
/// tiles for Daily / Collection / Shop / Settings. Staggered entrance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(playerSummaryProvider);
    final dailyReward = ref.watch(dailyViewProvider.select((v) => v.hasReward));
    final newPuffs = ref.watch(
      saveProvider.select((s) => s.newLevels.isNotEmpty),
    );

    Future<void> go(String route) async {
      await Navigator.of(context).pushNamed(route);
      // Coming back from a run or the shop may have changed the numbers.
      ref.invalidate(playerSummaryProvider);
    }

    return CozyScaffold(
      showBack: false,
      background: const Stack(
        fit: StackFit.expand,
        children: [SceneBackground(), FloatingParticles(count: 12)],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          final gap = r.s(10);
          var i = 0;
          Widget stagger(Widget child) =>
              StaggeredEntrance(index: i++, child: child);

          return Padding(
            padding: EdgeInsets.fromLTRB(r.s(18), r.s(8), r.s(18), r.s(12)),
            child: Column(
              children: [
                stagger(
                  Row(
                    children: [
                      StatChip(
                        icon: Icons.emoji_events_rounded,
                        iconColor: AppColors.sunshineDeep,
                        value: summary.bestScore,
                        semanticLabel: 'Best score',
                        height: r.s(38),
                      ),
                      const Spacer(),
                      StatChip(
                        icon: Icons.monetization_on_rounded,
                        iconColor: AppColors.sunshineDeep,
                        value: summary.coins,
                        semanticLabel: 'Coins',
                        height: r.s(38),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(14)),
                stagger(GameLogo(fontSize: r.s(r.isCompact ? 46 : 56))),
                Expanded(child: stagger(const HomeMascot())),
                // Play overlaps the front of the ledge, like a sign on it.
                stagger(
                  Transform.translate(
                    offset: Offset(0, -r.s(34)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(28)),
                      child: SoftButton(
                        label: 'Play',
                        icon: Icons.play_arrow_rounded,
                        height: r.s(76),
                        fontSize: r.s(34),
                        onTap: () => go(AppRoutes.game),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -r.s(18)),
                  child: stagger(
                    Row(
                      children: [
                        for (final (label, icon, color, route) in const [
                          (
                            'Daily',
                            Icons.event_available_rounded,
                            AppColors.candyPink,
                            AppRoutes.daily,
                          ),
                          (
                            'Collection',
                            Icons.menu_book_rounded,
                            AppColors.candyBlue,
                            AppRoutes.collection,
                          ),
                          (
                            'Shop',
                            Icons.storefront_rounded,
                            AppColors.candyPink,
                            AppRoutes.shop,
                          ),
                          (
                            'Settings',
                            Icons.settings_rounded,
                            AppColors.candyBlue,
                            AppRoutes.settings,
                          ),
                        ]) ...[
                          if (label != 'Daily') SizedBox(width: gap),
                          Expanded(
                            child: TileButton(
                              label: label,
                              icon: icon,
                              color: color,
                              height: r.s(86),
                              badge:
                                  (route == AppRoutes.daily && dailyReward) ||
                                  (route == AppRoutes.collection && newPuffs),
                              onTap: () => go(route),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                stagger(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RoundIconButton(
                        icon: Icons.school_rounded,
                        semanticLabel: 'How to play',
                        size: r.s(42),
                        color: AppColors.candyPurple,
                        onTap: () => go(AppRoutes.tutorial),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
