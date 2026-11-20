import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/feedback_service.dart';
import '../data/repositories/save_controller.dart';
import '../features/shop/shop_controller.dart';
import 'routes.dart';
import 'theme.dart';

class FluffyMergeApp extends ConsumerWidget {
  const FluffyMergeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts audio (music + sound effects) and keeps it in sync with the
    // saved settings for the app's lifetime.
    ref.watch(feedbackProvider);
    // Connects to the store at launch, so purchases that finished while
    // the app was closed (e.g. pending payments) are delivered.
    ref.watch(shopControllerProvider);
    final reducedMotion = ref.watch(
      saveProvider.select((s) => s.settings.reducedMotion),
    );
    return MaterialApp(
      title: 'Fluffy Merge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            // Respect the user's text size, but cap it so the HUD and jar
            // layout never break on the largest accessibility sizes.
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
            // The in-app "Reduced animation" setting works exactly like
            // the OS one, so every reduce-motion check honours both.
            disableAnimations: mq.disableAnimations || reducedMotion,
          ),
          child: child!,
        );
      },
    );
  }
}
