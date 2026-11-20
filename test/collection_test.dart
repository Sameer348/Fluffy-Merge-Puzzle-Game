import 'dart:convert';

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:fluffy_merge/features/collection/collection_screen.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

void main() {
  test('v1 → v2 upgrade: already-unlocked puffs count as seen', () async {
    SharedPreferences.setMockInitialValues({
      SaveStore.primaryKey: jsonEncode({
        'version': 1,
        'coins': 5,
        'unlockedLevels': [1, 2, 3],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(prefs);
    final d = store.load();
    await store.flush();
    expect(d.unlockedLevels, {1, 2, 3});
    expect(d.seenLevels, {1, 2, 3});
    expect(d.newLevels, isEmpty);
    expect(d.coins, 5);
    final raw = jsonDecode(prefs.getString(SaveStore.primaryKey)!) as Map;
    expect(raw['version'], SaveData.schemaVersion);
  });

  group('Collection screen', () {
    late SharedPreferences prefs;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> boot(
      WidgetTester tester, {
      Size size = const Size(393, 852),
      Set<int> unlocked = const {},
      Set<int> seen = const {},
    }) async {
      final save = SaveData.fresh().copyWith(
        unlockedLevels: unlocked,
        seenLevels: seen,
      );
      SharedPreferences.setMockInitialValues({
        SaveStore.primaryKey: jsonEncode(save.toJson()),
      });
      prefs = await SharedPreferences.getInstance();
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
    }

    testWidgets('locked, unlocked and NEW cards; visiting clears NEW', (
      tester,
    ) async {
      await boot(tester, unlocked: {1, 2, 3, 6}, seen: {1, 2});
      expect(
        find.bySemanticsLabel('Collection, reward waiting'),
        findsOneWidget,
        reason: 'home badge: two unseen puffs',
      );

      await tester.tap(find.text('Collection'));
      await advance(tester, 1200);
      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('4 / 12 Unlocked'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(8));
      final lavender = CreatureCatalog.byLevel(6);
      expect(
        find.bySemanticsLabel('${lavender.name}, level 6, new'),
        findsOneWidget,
      );
      expect(find.text('NEW'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Level 12, not discovered yet'),
        findsOneWidget,
      );
      expect(readSave(prefs).newLevels, isEmpty, reason: 'marked as seen');

      await tester.tap(find.bySemanticsLabel('Back'));
      await advance(tester, 900);
      expect(find.bySemanticsLabel('Collection, reward waiting'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail card: personality, faces, and a locked hint', (
      tester,
    ) async {
      await boot(tester, unlocked: {1, 2, 3}, seen: {1, 2, 3});
      await tester.tap(find.text('Collection'));
      await advance(tester, 1200);

      final lemon = CreatureCatalog.byLevel(3);
      await tester.tap(find.bySemanticsLabel('${lemon.name}, level 3'));
      await advance(tester);
      expect(find.text(lemon.personality), findsOneWidget);
      expect(
        find.text(
          'Merge two Berry Puffs to make one. '
          'Sometimes drops into the jar too.',
        ),
        findsOneWidget,
      );
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.bySemanticsLabel(lemon.name).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.bySemanticsLabel('Close'));
      await advance(tester);

      await tester.tap(find.bySemanticsLabel('Level 9, not discovered yet'));
      await advance(tester);
      expect(find.text('Not discovered yet. Keep merging!'), findsOneWidget);
      expect(find.textContaining('Merge two Bubble Puffs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, size, cols) in const [
      ('phone', Size(393, 852), 4),
      ('small phone', Size(360, 640), 4),
      ('tablet', Size(820, 1180), 6),
    ]) {
      testWidgets('$name: $cols columns, no overflow', (tester) async {
        await boot(tester, size: size, unlocked: {1, 2}, seen: {1, 2});
        await tester.tap(find.text('Collection'));
        await advance(tester, 1200);
        final firstRowY = tester
            .getTopLeft(find.bySemanticsLabel('Tiny Puff, level 1'))
            .dy;
        var inRow = 0;
        for (var l = 1; l <= 12; l++) {
          final spec = CreatureCatalog.byLevel(l);
          final label = l <= 2
              ? '${spec.name}, level $l'
              : 'Level $l, not discovered yet';
          final y = tester.getTopLeft(find.bySemanticsLabel(label)).dy;
          if ((y - firstRowY).abs() < 1) inRow++;
        }
        expect(inRow, cols);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
