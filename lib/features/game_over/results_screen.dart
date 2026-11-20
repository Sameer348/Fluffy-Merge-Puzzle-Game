import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ads/ad_service.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/progress_repository.dart';
import '../../game/models/creature_spec.dart';
import '../../game/models/run_result.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/common/floating_particles.dart';
import '../../widgets/common/staggered_entrance.dart';
import '../../widgets/common/wood_sign.dart';
import '../../widgets/creature/creature_view.dart';
import '../../widgets/scene/scene_background.dart';
import '../../widgets/score/bounce_on_change.dart';
import '../../widgets/score/stat_chip.dart';
import '../home/home_providers.dart';

/// "So Fluffy!" results: Fluffy cheering over a wooden sign, a cream panel
/// with score (counting up), best score, highest creature and coins
/// earned, then Retry / Home and an optional "Watch Ad → 2× Reward".
///
/// The run is already saved when this screen opens; the ad bonus only
/// adds coins, once.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.result});

  final RunResult result;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _doubled = false;
  bool _watching = false;

  int get _coins => widget.result.coinsEarned * (_doubled ? 2 : 1);

  Future<void> _watchAd() async {
    if (_watching || _doubled) return;
    setState(() => _watching = true);
    final ok = await ref
        .read(adServiceProvider)
        .showRewarded(placement: 'results_2x');
    if (!mounted) return;
    if (ok) {
      await ref
          .read(progressRepositoryProvider)
          .addCoins(widget.result.coinsEarned);
    }
    if (!mounted) return;
    setState(() {
      _watching = false;
      _doubled = ok;
    });
  }

  void _retry() => Navigator.of(context).pushReplacementNamed(AppRoutes.game);

  void _home() {
    ref.invalidate(playerSummaryProvider);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final ads = ref.watch(adServiceProvider);
    final canDouble = ads.rewardedAvailable && res.coinsEarned > 0;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SceneBackground()),
          const Positioned.fill(child: FloatingParticles(count: 18)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final r = Responsive.of(constraints.biggest);
                var i = 0;
                Widget stagger(Widget c) =>
                    StaggeredEntrance(index: i++, child: c);
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(24),
                      vertical: r.s(12),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          stagger(
                            CreatureView(
                              spec: CreatureCatalog.mascot,
                              size: r.s(r.isCompact ? 110 : 140),
                              expression: CreatureExpression.excited,
                            ),
                          ),
                          stagger(
                            Transform.translate(
                              offset: Offset(0, -r.s(18)),
                              child: WoodSign(
                                text: 'So Fluffy!',
                                fontSize: r.s(34),
                              ),
                            ),
                          ),
                          stagger(_panel(r, res)),
                          SizedBox(height: r.s(16)),
                          stagger(
                            SoftButton(
                              label: 'Retry',
                              icon: Icons.refresh_rounded,
                              candy: CandyColor.green,
                              height: r.s(60),
                              fontSize: r.s(24),
                              onTap: _retry,
                            ),
                          ),
                          SizedBox(height: r.s(10)),
                          stagger(
                            SoftButton(
                              label: 'Home',
                              icon: Icons.home_rounded,
                              candy: CandyColor.blue,
                              height: r.s(60),
                              fontSize: r.s(24),
                              onTap: _home,
                            ),
                          ),
                          if (canDouble) ...[
                            SizedBox(height: r.s(10)),
                            stagger(
                              SoftButton(
                                label: _doubled
                                    ? 'Reward doubled!'
                                    : (_watching
                                          ? 'Playing ad...'
                                          : 'Watch Ad for 2X Reward'),
                                icon: _doubled
                                    ? Icons.check_circle_rounded
                                    : Icons.ondemand_video_rounded,
                                candy: CandyColor.yellow,
                                darkText: true,
                                height: r.s(56),
                                fontSize: r.s(19),
                                onTap: _doubled || _watching ? null : _watchAd,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Responsive r, RunResult res) {
    final spec = CreatureCatalog.byLevel(res.highestLevel);
    final label = AppText.display(r.s(18), color: AppColors.woodDark);
    final big = AppText.display(r.s(40)).copyWith(fontWeight: FontWeight.w700);
    final mid = AppText.display(r.s(28)).copyWith(fontWeight: FontWeight.w700);

    Widget row({required Widget child}) => Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: r.s(8)),
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(12)),
      decoration: BoxDecoration(
        color: AppColors.panelInset,
        borderRadius: BorderRadius.circular(r.s(16)),
      ),
      child: child,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(r.s(14), r.s(14), r.s(14), r.s(14)),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(r.s(26)),
        border: Border.all(color: AppColors.panelBorder, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33975A2A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (res.isNewBest)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.s(14),
                vertical: r.s(4),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [AppColors.candyPinkTop, AppColors.candyPink],
                ),
              ),
              child: Text(
                'NEW BEST!',
                style: AppText.display(r.s(15), color: AppColors.white),
              ),
            ),
          Semantics(
            label: 'Score ${res.score}',
            excludeSemantics: true,
            child: Column(
              children: [
                Text('Score', style: label),
                AnimatedCounter(
                  value: res.score,
                  style: big,
                  duration: const Duration(milliseconds: 1100),
                ),
              ],
            ),
          ),
          row(
            child: Semantics(
              label: 'Best score ${res.bestScore}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text('Best Score', style: label),
                  Text(formatNumber(res.bestScore), style: mid),
                ],
              ),
            ),
          ),
          row(
            child: Semantics(
              label: 'Highest creature: ${spec.name}, level ${spec.level}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text('Highest Creature', style: label),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CreatureView(spec: spec, size: r.s(56)),
                      SizedBox(width: r.s(8)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lv. ${spec.level}', style: mid),
                          Text(
                            spec.name,
                            style: AppText.body(
                              r.s(13),
                              color: AppColors.softBrown,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          row(
            child: Semantics(
              label: 'Coins earned $_coins',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text('Coins Earned', style: label),
                  BounceOnChange(
                    value: _coins,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          color: AppColors.sunshineDeep,
                          size: r.s(30),
                        ),
                        SizedBox(width: r.s(6)),
                        AnimatedCounter(value: _coins, style: mid),
                      ],
                    ),
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
