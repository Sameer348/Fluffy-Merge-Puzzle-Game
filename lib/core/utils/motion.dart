import 'package:flutter/widgets.dart';

/// Single place to ask "should we animate?". Today it follows the OS
/// reduce-motion setting; Phase 11/15 also ORs in the in-app
/// "Reduced animation" toggle.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
