import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/save_controller.dart';
import '../../game/fluffy_game.dart';
import '../../game/models/creature_spec.dart';
import '../../game/models/power_up.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/creature/creature_view.dart';
import '../gameplay/widgets/power_up_bar.dart';

/// How to Play: the rules in five short cards, each with a picture made
/// from the game's own art. "Got it!" marks the tutorial as seen.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CozyScaffold(
      title: 'How to Play',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          final puff = r.s(46);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.s(18), r.s(8), r.s(18), r.s(24)),
            child: Column(
              children: [
                _Step(
                  r: r,
                  number: 1,
                  title: 'Drag to aim, release to drop',
                  body:
                      'Slide your finger across the jar, then let go to '
                      'drop the puff you are holding.',
                  art: Icon(
                    Icons.touch_app_rounded,
                    size: puff,
                    color: AppColors.candyPink,
                  ),
                ),
                _Step(
                  r: r,
                  number: 2,
                  title: 'Two alike make one bigger',
                  body:
                      'When two puffs of the same kind touch, they merge '
                      'into the next, fluffier puff.',
                  art: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CreatureView(
                        spec: CreatureCatalog.byLevel(1),
                        size: puff * 0.7,
                      ),
                      Text(' + ', style: AppText.display(r.s(18))),
                      CreatureView(
                        spec: CreatureCatalog.byLevel(1),
                        size: puff * 0.7,
                      ),
                      Text(' = ', style: AppText.display(r.s(18))),
                      CreatureView(
                        spec: CreatureCatalog.byLevel(2),
                        size: puff * 0.9,
                        expression: CreatureExpression.excited,
                      ),
                    ],
                  ),
                ),
                _Step(
                  r: r,
                  number: 3,
                  title: 'Chain merges for combos',
                  body:
                      'Merges in quick succession build a combo and '
                      'multiply your points. Bigger puffs earn coins.',
                  art: Icon(
                    Icons.auto_awesome_rounded,
                    size: puff,
                    color: AppColors.sunshineDeep,
                  ),
                ),
                _Step(
                  r: r,
                  number: 4,
                  title: 'Mind the dotted line',
                  body:
                      'If puffs stay above the dotted line for a few '
                      'seconds, the jar overflows and the run ends.',
                  art: Icon(
                    Icons.warning_amber_rounded,
                    size: puff,
                    color: AppColors.candyPink,
                  ),
                ),
                _Step(
                  r: r,
                  number: 5,
                  title: 'Power-ups help when stuck',
                  body:
                      'Sweep clears small puffs, Pop removes one, Grow '
                      'levels one up and Shake loosens the pile. Reach new '
                      'levels (or a ${FluffyGame.comboRewardAt}x combo) to '
                      'earn more.',
                  art: Wrap(
                    spacing: r.s(4),
                    children: [
                      for (final p in PowerUp.values)
                        PowerUpIcon(kind: p, size: puff * 0.62),
                    ],
                  ),
                ),
                SizedBox(height: r.s(16)),
                SoftButton(
                  label: 'Got it!',
                  icon: Icons.check_rounded,
                  candy: CandyColor.green,
                  height: r.s(56),
                  fontSize: r.s(22),
                  onTap: () {
                    ref.read(saveProvider.notifier).completeTutorial();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.r,
    required this.number,
    required this.title,
    required this.body,
    required this.art,
  });

  final Responsive r;
  final int number;
  final String title;
  final String body;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Step $number. $title. $body',
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsets.only(bottom: r.s(12)),
          padding: EdgeInsets.all(r.s(14)),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(r.s(22)),
            border: Border.all(color: AppColors.panelBorder, width: 3),
          ),
          child: Row(
            children: [
              SizedBox(
                width: r.s(96),
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: art),
                ),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$number. $title',
                      style: AppText.display(
                        r.s(18),
                        color: AppColors.woodDark,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      body,
                      style: AppText.body(
                        r.s(14),
                        color: AppColors.softBrown,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
