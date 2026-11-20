import 'dart:async';

import 'package:fluffy_merge/app/theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file. Tests have no network, so text uses plain
/// font-family styles instead of the google_fonts loader.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppText.useGoogleFonts = false;
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
