import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/coming_soon.dart';

/// Placeholder — implemented in a later phase.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'How to Play',
    icon: Icons.school_rounded,
    color: AppColors.sky,
  );
}
