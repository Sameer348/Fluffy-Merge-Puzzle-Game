import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/save_controller.dart';
import '../../game/models/creature_spec.dart';
import '../../widgets/buttons/pressable_scale.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/common/staggered_entrance.dart';
import '../../widgets/creature/living_creature.dart';
import 'creature_detail_dialog.dart';

/// Creature Collection: a grid of all 12 puffs (4 columns on phones, 6 on
/// tablets). Discovered ones are in full colour and gently alive; the rest
/// are silhouettes with a lock. Newly discovered puffs wear a NEW ribbon
/// for this visit. Tap any card for details.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMicroseconds / 1e6,
  );

  /// NEW tags shown during this visit (captured before they're cleared).
  late final Set<int> _newThisVisit = {...ref.read(saveProvider).newLevels};

  @override
  void initState() {
    super.initState();
    _newThisVisit; // capture before clearing
    // Opening the collection counts as seeing everything in it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(saveProvider.notifier).markLevelsSeen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(saveProvider.select((s) => s.unlockedLevels));
    return CozyScaffold(
      title: 'Collection',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          // Device class from the whole screen: on tablets the content area
          // is width-capped and would otherwise look like a phone.
          final cols = Responsive.fromContext(context).gridColumns;
          final gap = r.s(10);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(6), r.s(16), r.s(24)),
            child: Container(
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(r.s(26)),
                border: Border.all(color: AppColors.panelBorder, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33975A2A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: 0.78,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final spec in CreatureCatalog.all)
                        StaggeredEntrance(
                          index: spec.level ~/ 2,
                          child: _CreatureCard(
                            spec: spec,
                            unlocked: unlocked.contains(spec.level),
                            isNew: _newThisVisit.contains(spec.level),
                            time: _time,
                            scale: r.scale,
                            onTap: () => showCreatureDetail(
                              context,
                              spec: spec,
                              unlocked: unlocked.contains(spec.level),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: r.s(14)),
                  _Progress(
                    count: unlocked.length,
                    total: GameConstants.maxLevel,
                    scale: r.scale,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreatureCard extends StatelessWidget {
  const _CreatureCard({
    required this.spec,
    required this.unlocked,
    required this.isNew,
    required this.time,
    required this.scale,
    required this.onTap,
  });

  final CreatureSpec spec;
  final bool unlocked;
  final bool isNew;
  final ValueNotifier<double> time;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final label = unlocked
        ? '${spec.name}, level ${spec.level}${isNew ? ', new' : ''}'
        : 'Level ${spec.level}, not discovered yet';
    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(
                color: unlocked
                    ? spec.shade.withValues(alpha: 0.5)
                    : AppColors.panelBorder,
                width: 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: unlocked
                    ? [AppColors.white, spec.light.withValues(alpha: 0.7)]
                    : const [Color(0xFFF3E7DA), Color(0xFFE8D9CA)],
              ),
            ),
            padding: EdgeInsets.fromLTRB(4 * s, 6 * s, 4 * s, 4 * s),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Stack(
                      alignment: Alignment.center,
                      children: [
                        LivingCreature(
                          spec: spec,
                          time: time,
                          size: c.biggest.shortestSide,
                          silhouette: !unlocked,
                        ),
                        if (!unlocked)
                          Icon(
                            Icons.lock_rounded,
                            color: AppColors.white,
                            size: c.biggest.shortestSide * 0.3,
                          ),
                      ],
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    unlocked ? spec.name : '???',
                    maxLines: 1,
                    style: AppText.display(12 * s, color: AppColors.woodDark),
                  ),
                ),
                Text(
                  'Lv. ${spec.level}',
                  style: AppText.body(10 * s, color: AppColors.softBrown),
                ),
              ],
            ),
          ),
          if (isNew && unlocked)
            Positioned(
              top: -6 * s,
              right: -4 * s,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * s,
                  vertical: 2 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.white, width: 1.5),
                  gradient: const LinearGradient(
                    colors: [AppColors.candyPinkTop, AppColors.candyPink],
                  ),
                ),
                child: Text(
                  'NEW',
                  style: AppText.display(10 * s, color: AppColors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.count,
    required this.total,
    required this.scale,
  });

  final int count;
  final int total;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      label: '$count of $total discovered',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.candyPurple,
                size: 20 * s,
              ),
              SizedBox(width: 6 * s),
              Text(
                '$count / $total Unlocked',
                style: AppText.display(18 * s, color: AppColors.woodDark),
              ),
            ],
          ),
          SizedBox(height: 6 * s),
          Container(
            height: 14 * s,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.panelInset,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.panelBorder, width: 1.5),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: total == 0 ? 0 : (count / total).clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [AppColors.candyPurpleTop, AppColors.candyPurple],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
