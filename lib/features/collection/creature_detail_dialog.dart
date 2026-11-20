import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/utils/motion.dart';
import '../../game/models/creature_spec.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/common/wood_sign.dart';
import '../../widgets/creature/living_creature.dart';

/// Detail card for one creature. Discovered: big living creature (tap it to
/// cycle through its faces), level, personality and how it's made.
/// Undiscovered: silhouette and a hint.
Future<void> showCreatureDetail(
  BuildContext context, {
  required CreatureSpec spec,
  required bool unlocked,
}) {
  final reduce = reduceMotion(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x664A3F45),
    transitionDuration: Duration(milliseconds: reduce ? 120 : 240),
    pageBuilder: (context, _, _) =>
        _CreatureDetail(spec: spec, unlocked: unlocked),
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
}

class _CreatureDetail extends StatefulWidget {
  const _CreatureDetail({required this.spec, required this.unlocked});

  final CreatureSpec spec;
  final bool unlocked;

  @override
  State<_CreatureDetail> createState() => _CreatureDetailState();
}

class _CreatureDetailState extends State<_CreatureDetail>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMicroseconds / 1e6,
  );
  int _face = 0;

  static const _faces = [
    CreatureExpression.happy,
    CreatureExpression.excited,
    CreatureExpression.wink,
    CreatureExpression.surprised,
    CreatureExpression.squished,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  String get _howToMake {
    final spec = widget.spec;
    if (spec.level == 1) return 'Drops into the jar all the time.';
    final prev = CreatureCatalog.byLevel(spec.level - 1).name;
    final drops = spec.level <= GameConstants.maxSpawnLevel
        ? ' Sometimes drops into the jar too.'
        : '';
    return 'Merge two ${prev}s to make one.$drops';
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final open = widget.unlocked;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
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
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: open
                            ? () => setState(
                                () => _face = (_face + 1) % _faces.length,
                              )
                            : null,
                        child: LivingCreature(
                          spec: spec,
                          time: _time,
                          size: 150,
                          silhouette: !open,
                          expression: _faces[_face],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lv. ${spec.level}',
                        style: AppText.display(
                          20,
                          color: AppColors.candyPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        open
                            ? spec.personality
                            : 'Not discovered yet. Keep merging!',
                        textAlign: TextAlign.center,
                        style: AppText.body(16, color: AppColors.woodDark),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.panelInset,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _howToMake,
                          textAlign: TextAlign.center,
                          style: AppText.body(14, color: AppColors.softBrown),
                        ),
                      ),
                      if (open) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Tap ${spec.name} to see another face',
                          style: AppText.body(12, color: AppColors.softBrown),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SoftButton(
                        label: 'Close',
                        candy: CandyColor.blue,
                        height: 50,
                        fontSize: 19,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                WoodSign(text: open ? spec.name : '???', fontSize: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
