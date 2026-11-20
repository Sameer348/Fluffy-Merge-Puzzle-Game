import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../game/models/creature_spec.dart';
import '../../widgets/creature/creature_view.dart';

/// Short branded splash: a puff pops in with a bouncy scale, the title fades
/// up, then we hand off to Home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.fromContext(context);
    final puff = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    final title = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: puff,
                child: CreatureView(
                  spec: CreatureCatalog.byLevel(2),
                  size: r.s(150),
                ),
              ),
              SizedBox(height: r.s(24)),
              FadeTransition(
                opacity: title,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(title),
                  child: Text('Fluffy Merge', style: AppText.display(r.s(34))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
