import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/coming_soon.dart';

/// Placeholder — implemented in a later phase.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Shop',
    icon: Icons.storefront_rounded,
    color: AppColors.mintDeep,
  );
}
