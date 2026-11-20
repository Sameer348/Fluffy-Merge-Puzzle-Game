import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/constants/app_colors.dart';
import 'data/local/preferences_provider.dart';
import 'game/rendering/creature_renderer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start loading the save while the platform call runs.
  final prefsLoading = SharedPreferences.getInstance();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.peachCream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final prefs = await prefsLoading;
  WidgetsBinding.instance.addObserver(_MemoryPressure());
  // Font licenses show in Settings → Licenses.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Fredoka', 'Nunito'], text);
  });

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FluffyMergeApp(),
    ),
  );
}

/// Drops the creature drawing cache when the OS asks apps to free memory;
/// it rebuilds itself lazily on the next frame.
class _MemoryPressure with WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() => CreatureRenderer.clearCache();
}
