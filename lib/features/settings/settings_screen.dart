import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/coming_soon.dart';

/// Placeholder — implemented in a later phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Settings',
    icon: Icons.tune_rounded,
    color: AppColors.softBrown,
  );
}
