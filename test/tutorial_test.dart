import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/features/tutorial/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

void main() {
  Future<void> advance(WidgetTester tester, [int ms = 600]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final size in const [Size(360, 640), Size(393, 852), Size(820, 1180)]) {
    testWidgets('How to Play: five steps, Got it! saves ($size)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 2400);

      // Only finished screens are reachable from Home.
      expect(find.bySemanticsLabel('Leaderboard'), findsNothing);
      expect(find.bySemanticsLabel('Achievements'), findsNothing);
      expect(find.textContaining('coming soon'), findsNothing);

      await tester.tap(find.bySemanticsLabel('How to play'));
      await advance(tester, 1000);
      expect(find.byType(TutorialScreen), findsOneWidget);
      for (var n = 1; n <= 5; n++) {
        expect(find.bySemanticsLabel(RegExp('^Step $n\\. ')), findsOneWidget);
      }
      expect(readSave(prefs).tutorialCompleted, isFalse);

      final gotIt = find.bySemanticsLabel('Got it!');
      await tester.scrollUntilVisible(
        gotIt,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(gotIt);
      await advance(tester, 900);
      expect(readSave(prefs).tutorialCompleted, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
