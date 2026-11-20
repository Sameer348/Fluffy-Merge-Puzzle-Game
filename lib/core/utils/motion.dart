import 'package:flutter/widgets.dart';

/// Single place to ask "should we animate?". True when the OS reduce-motion
/// setting or the in-app "Reduced animation" setting is on (the app shell
/// merges the latter into MediaQuery.disableAnimations).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
