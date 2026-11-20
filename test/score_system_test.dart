import 'package:fluffy_merge/data/repositories/progress_repository.dart';
import 'package:fluffy_merge/game/models/merge_event.dart';
import 'package:fluffy_merge/game/systems/score_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MergeEvent _merge(int level, double t, {bool rainbow = false}) => MergeEvent(
  fromLevel: level,
  resultLevel: rainbow ? null : level + 1,
  position: Vector2.zero(),
  time: t,
  createdId: rainbow ? null : 1,
);

void main() {
  group('ScoreSystem', () {
    late ScoreSystem s;
    setUp(() => s = ScoreSystem());
    tearDown(() => s.dispose());

    test('base points grow with level: 10, 30, 60, 100, 150', () {
      expect(
        [for (var l = 1; l <= 5; l++) ScoreSystem.basePoints(l)],
        [10, 30, 60, 100, 150],
      );
    });

    test('quick Tiny merges: +10, +20, +40, +80 (the spec example)', () {
      final pts = [
        for (var i = 0; i < 4; i++) s.onMerge(_merge(1, i * 0.5)).points,
      ];
      expect(pts, [10, 20, 40, 80]);
      expect(s.score.value, 150);
      expect(s.combo.value, 4);
      expect(s.bestCombo, 4);
    });

    test('a pause longer than the window resets the combo', () {
      s.onMerge(_merge(1, 0));
      s.onMerge(_merge(1, 0.5));
      final late = s.onMerge(_merge(1, 0.5 + ScoreSystem.comboWindow + 0.01));
      expect(late.combo, 1);
      expect(late.multiplier, 1);
    });

    test('tick() ends an expired combo for the HUD', () {
      s.onMerge(_merge(1, 0));
      s.tick(ScoreSystem.comboWindow - 0.01);
      expect(s.combo.value, 1);
      s.tick(ScoreSystem.comboWindow + 0.01);
      expect(s.combo.value, 0);
    });

    test('multiplier caps at ×16', () {
      expect(ScoreSystem.multiplierFor(1), 1);
      expect(ScoreSystem.multiplierFor(5), 16);
      expect(ScoreSystem.multiplierFor(40), ScoreSystem.maxMultiplier);
    });

    test('labels follow the combo', () {
      expect(
        [for (var c = 1; c <= 6; c++) ScoreSystem.labelFor(c)],
        [
          'MERGE!',
          'COMBO x2!',
          'COMBO x3!',
          'AMAZING!',
          'SUPER MERGE!',
          'SUPER MERGE!',
        ],
      );
      expect(ScoreSystem.labelFor(1, rainbow: true), 'RAINBOW BURST!');
    });

    test('coins: level 4+ pays (level − 3), combos of 3+ add one', () {
      expect(ScoreSystem.coinsFor(1, 1), 0);
      expect(ScoreSystem.coinsFor(3, 1), 0);
      expect(ScoreSystem.coinsFor(4, 1), 1);
      expect(ScoreSystem.coinsFor(8, 1), 5);
      expect(ScoreSystem.coinsFor(1, 3), 1);
      for (var i = 0; i < 3; i++) {
        s.onMerge(_merge(4, i * 0.3));
      }
      expect(s.coins.value, 1 + 1 + 2);
    });

    test('rainbow clear: big fixed bonus and coins', () {
      final a = s.onMerge(_merge(12, 0, rainbow: true));
      expect(a.points, ScoreSystem.rainbowClearPoints);
      expect(a.coins, ScoreSystem.rainbowClearCoins);
      expect(a.label, 'RAINBOW BURST!');
    });

    test('NEW BEST fires once, only when beating a previous best', () {
      final b = ScoreSystem(bestAtStart: 25);
      b.onMerge(_merge(1, 0)); // 10
      expect(b.takeNewBest(), isFalse);
      b.onMerge(_merge(2, 5)); // +30 → 40
      expect(b.takeNewBest(), isTrue);
      b.onMerge(_merge(2, 10));
      expect(b.takeNewBest(), isFalse);
      b.dispose();

      final first = ScoreSystem(); // no previous best → no banner
      first.onMerge(_merge(5, 0));
      expect(first.takeNewBest(), isFalse);
      first.dispose();
    });
  });

  group('ProgressRepository', () {
    test('records best score and adds coins to the wallet', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProgressRepository(await SharedPreferences.getInstance());
      var r = await repo.recordRun(score: 500, coinsEarned: 7);
      expect(r.isNewBest, isTrue);
      expect(repo.bestScore, 500);
      expect(repo.coins, 7);

      r = await repo.recordRun(score: 300, coinsEarned: 3);
      expect(r.isNewBest, isFalse);
      expect(r.bestScore, 500);
      expect(repo.bestScore, 500);
      expect(repo.coins, 10);
    });
  });
}
