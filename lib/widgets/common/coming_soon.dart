import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'cozy_scaffold.dart';

/// Friendly placeholder for screens built in later phases. Keeps navigation
/// fully testable from Phase 1 on.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.message = 'Our puffs are still knitting this room.\nCheck back soon!',
  });

  final String title;
  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return CozyScaffold(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.xl),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.panelBorder, width: 3),
              borderRadius: AppSizes.cardRadius,
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: color),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(title, style: t.headlineMedium),
                const SizedBox(height: AppSizes.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: t.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
