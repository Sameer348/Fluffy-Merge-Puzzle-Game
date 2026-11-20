import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/feedback_service.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/common/staggered_entrance.dart';
import '../../widgets/score/stat_chip.dart';
import '../gameplay/widgets/power_up_bar.dart';
import 'daily_controller.dart';
import 'model/streak.dart';

/// Daily Challenge: today's goal with a progress bar, reward and time left
/// (Play Now / Claim!), and the 7-day streak with today's claim.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps "Time left" fresh and rolls over to the next day's challenge
    // if the screen is open at midnight.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(dailyViewProvider);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  DailyController get _daily => ref.read(dailyControllerProvider);

  void _claimChallenge(DailyView v) {
    if (_daily.claimChallenge()) {
      ref.read(feedbackProvider).reward();
      _toast(
        'Claimed ${v.challenge.coins} coins and 1 ${v.challenge.powerUp.label}!',
      );
    }
  }

  void _claimStreak() {
    final r = _daily.claimStreak();
    if (r == null) return;
    ref.read(feedbackProvider).reward();
    final gifts = r.powerUps.entries
        .map((e) => '${e.value} ${e.key.label}')
        .join(' + ');
    _toast('Claimed ${r.coins} coins${gifts.isEmpty ? '' : ' + $gifts'}!');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.panelBorder, width: 2),
          ),
          content: Text(
            message,
            style: AppText.body(15, color: AppColors.woodDark),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(dailyViewProvider);
    return CozyScaffold(
      title: 'Daily Challenge',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.s(20), r.s(8), r.s(20), r.s(24)),
            child: Column(
              children: [
                StaggeredEntrance(index: 0, child: _challengeCard(r, v)),
                SizedBox(height: r.s(18)),
                StaggeredEntrance(index: 1, child: _streakCard(r, v)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _panel(Responsive r, {required Widget child}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(r.s(16)),
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
    child: child,
  );

  Widget _challengeCard(Responsive r, DailyView v) {
    final c = v.challenge;
    final label = AppText.body(r.s(14), color: AppColors.softBrown);
    final h = v.timeLeft.inHours;
    final m = v.timeLeft.inMinutes % 60;

    final Widget action;
    if (v.claimed) {
      action = SoftButton(
        label: 'Claimed',
        icon: Icons.check_circle_rounded,
        candy: CandyColor.blue,
        height: r.s(54),
        fontSize: r.s(21),
        onTap: null,
      );
    } else if (v.completed) {
      action = SoftButton(
        label: 'Claim!',
        icon: Icons.redeem_rounded,
        candy: CandyColor.pink,
        height: r.s(58),
        fontSize: r.s(24),
        onTap: () => _claimChallenge(v),
      );
    } else {
      action = SoftButton(
        label: 'Play Now',
        icon: Icons.play_arrow_rounded,
        candy: CandyColor.green,
        height: r.s(58),
        fontSize: r.s(24),
        onTap: () {
          ref.read(analyticsProvider).log(
            AnalyticsEvent.dailyChallengeStarted,
            {'kind': v.challenge.kind.name, 'target': v.challenge.target},
          );
          Navigator.of(context).pushNamed(AppRoutes.game);
        },
      );
    }

    return _panel(
      r,
      child: Column(
        children: [
          Text('Today\'s challenge', style: label),
          SizedBox(height: r.s(2)),
          Text(
            c.title,
            textAlign: TextAlign.center,
            style: AppText.display(r.s(28))
                .copyWith(fontWeight: FontWeight.w700),
          ),
          Text(c.detail, textAlign: TextAlign.center, style: label),
          SizedBox(height: r.s(12)),
          _ProgressBar(
            value: v.progress / c.target,
            height: r.s(26),
            label: '${formatNumber(v.progress)} / ${formatNumber(c.target)}',
          ),
          SizedBox(height: r.s(14)),
          Text(
            'Reward',
            style: AppText.display(r.s(18), color: AppColors.woodDark),
          ),
          SizedBox(height: r.s(4)),
          Semantics(
            label: 'Reward: ${c.coins} coins and 1 ${c.powerUp.label}',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.sunshineDeep,
                  size: r.s(30),
                ),
                SizedBox(width: r.s(4)),
                Text('${c.coins}', style: AppText.display(r.s(24))),
                SizedBox(width: r.s(18)),
                PowerUpIcon(kind: c.powerUp, size: r.s(34)),
                SizedBox(width: r.s(4)),
                Text('x1', style: AppText.display(r.s(22))),
              ],
            ),
          ),
          SizedBox(height: r.s(10)),
          Text(
            'Time left: ${h}h ${m}m',
            style: AppText.body(r.s(15), color: AppColors.woodDark),
          ),
          SizedBox(height: r.s(12)),
          action,
        ],
      ),
    );
  }

  Widget _streakCard(Responsive r, DailyView v) {
    final s = v.streak;
    return _panel(
      r,
      child: Column(
        children: [
          Text(
            '7-Day Streak',
            style: AppText.display(r.s(22))
                .copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Come back every day for bigger rewards.',
            style: AppText.body(r.s(13), color: AppColors.softBrown),
          ),
          SizedBox(height: r.s(12)),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) SizedBox(width: r.s(5)),
                Expanded(
                  child: _DayTile(
                    day: d,
                    reward: Streak.rewards[d - 1],
                    done: d <= s.daysDone,
                    today: d == s.dayToClaim && !s.claimedToday,
                    scale: r.scale,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: r.s(14)),
          s.claimedToday
              ? Text(
                  'Day ${s.dayToClaim} claimed. See you tomorrow!',
                  style: AppText.body(r.s(15), color: AppColors.woodDark),
                )
              : SoftButton(
                  label: 'Claim Day ${s.dayToClaim}',
                  icon: Icons.card_giftcard_rounded,
                  candy: CandyColor.yellow,
                  darkText: true,
                  height: r.s(54),
                  fontSize: r.s(21),
                  onTap: _claimStreak,
                ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.height,
    required this.label,
  });

  final double value;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress $label',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.panelInset,
          borderRadius: BorderRadius.circular(height),
          border: Border.all(color: AppColors.panelBorder, width: 2),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                widthFactor: value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.candyYellowTop, AppColors.candyYellow],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: FittedBox(
                child: Text(
                  label,
                  style: AppText.display(
                    height * 0.55,
                    color: AppColors.woodDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatefulWidget {
  const _DayTile({
    required this.day,
    required this.reward,
    required this.done,
    required this.today,
    required this.scale,
  });

  final int day;
  final StreakReward reward;
  final bool done;
  final bool today;
  final double scale;

  @override
  State<_DayTile> createState() => _DayTileState();
}

class _DayTileState extends State<_DayTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_DayTile old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.today && !reduceMotion(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final w = widget;
    final state = w.done ? 'claimed' : (w.today ? 'ready to claim' : 'locked');
    final icon = w.done
        ? Icons.check_circle_rounded
        : (w.reward.isGift
              ? Icons.card_giftcard_rounded
              : Icons.monetization_on_rounded);
    final color = w.done
        ? AppColors.candyGreen
        : (w.reward.isGift ? AppColors.candyPink : AppColors.sunshineDeep);
    return Semantics(
      label:
          'Day ${w.day}, ${w.reward.coins} coins'
          '${w.reward.isGift ? ' and a gift' : ''}, $state',
      excludeSemantics: true,
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.08).animate(_pulse),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 6 * s),
          decoration: BoxDecoration(
            color: w.today ? const Color(0xFFFFF3C4) : AppColors.panelInset,
            borderRadius: BorderRadius.circular(12 * s),
            border: Border.all(
              color: w.today ? AppColors.candyYellow : AppColors.panelBorder,
              width: w.today ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22 * s),
              FittedBox(
                child: Text(
                  'Day ${w.day}',
                  style: AppText.body(11 * s, color: AppColors.woodDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
