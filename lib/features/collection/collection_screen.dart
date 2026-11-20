import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/coming_soon.dart';

/// Placeholder — implemented in a later phase.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Collection',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.lavender,
  );
}
