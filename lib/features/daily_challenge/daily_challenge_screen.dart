import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/coming_soon.dart';

/// Placeholder — implemented in a later phase.
class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Daily Challenge',
    icon: Icons.calendar_today_rounded,
    color: AppColors.sunshineDeep,
  );
}
