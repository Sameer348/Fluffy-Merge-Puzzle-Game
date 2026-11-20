import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/systems/merge_detector.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements MergeCandidate {
  _Fake(this.id, this.level);

  @override
  final int id;

  @override
  int level;

  bool removed = false;

  @override
  bool claimedForMerge = false;

  @override
  bool get canMerge => !removed && !claimedForMerge;

  @override
  String toString() => '#$id';
}

void main() {
  late MergeDetector<_Fake> d;
  setUp(() => d = MergeDetector<_Fake>());

  test('same level touching → exactly one pair, emitted once', () {
    final a = _Fake(1, 3), b = _Fake(2, 3);
    d.beginTouch(a, b);
    d.beginTouch(b, a); // both bodies report the same contact
    final pairs = d.collect();
    expect(pairs, hasLength(1));
    expect(pairs.single.a, a, reason: 'older creature first');
    expect(pairs.single.b, b);
    expect(a.claimedForMerge && b.claimedForMerge, isTrue);
    expect(d.collect(), isEmpty, reason: 'no duplicate merge events');
  });

  test('different levels never merge', () {
    d.beginTouch(_Fake(1, 2), _Fake(2, 3));
    expect(d.collect(), isEmpty);
    expect(d.touchingPairCount, 1, reason: 'still tracked while touching');
  });

  test(
    'three touching same-level creatures → one merge, no creature twice',
    () {
      final a = _Fake(1, 1), b = _Fake(2, 1), c = _Fake(3, 1);
      d
        ..beginTouch(a, b)
        ..beginTouch(b, c)
        ..beginTouch(a, c);
      final pairs = d.collect();
      expect(pairs, hasLength(1));
      expect({pairs.single.a, pairs.single.b}, {a, b});
      // c's pairs were with now-claimed creatures → dropped as stale.
      expect(d.collect(), isEmpty);
      expect(d.touchingPairCount, 0);
    },
  );

  test('first touch merges first', () {
    final a = _Fake(1, 1), b = _Fake(2, 1), c = _Fake(3, 1);
    d
      ..beginTouch(a, c) // touched first
      ..beginTouch(a, b);
    final pair = d.collect().single;
    expect({pair.a, pair.b}, {a, c});
  });

  test('independent pairs merge in the same frame', () {
    final a = _Fake(1, 1), b = _Fake(2, 1), c = _Fake(3, 4), e = _Fake(4, 4);
    d
      ..beginTouch(a, b)
      ..beginTouch(c, e);
    expect(d.collect(), hasLength(2));
  });

  test('level change while already touching is detected (no new contact)', () {
    final a = _Fake(1, 1), b = _Fake(2, 2);
    d.beginTouch(a, b);
    expect(d.collect(), isEmpty);
    a.level = 2; // e.g. GROW on a sleeping creature
    expect(d.collect(), hasLength(1));
  });

  test('end touch and forget stop tracking', () {
    final a = _Fake(1, 1), b = _Fake(2, 1), c = _Fake(3, 1);
    d
      ..beginTouch(a, b)
      ..endTouch(b, a);
    expect(d.collect(), isEmpty);

    d
      ..beginTouch(a, c)
      ..forget(c);
    expect(d.touchingPairCount, 0);
    expect(d.collect(), isEmpty);
  });

  test('removed creatures are dropped even without forget()', () {
    final a = _Fake(1, 1), b = _Fake(2, 1);
    d.beginTouch(a, b);
    b.removed = true;
    expect(d.collect(), isEmpty);
    expect(d.touchingPairCount, 0);
  });

  test('result level: next level, or null for two max-level creatures', () {
    final lo = d..beginTouch(_Fake(1, 5), _Fake(2, 5));
    expect(lo.collect().single.resultLevel, 6);
    d.beginTouch(
      _Fake(3, GameConstants.maxLevel),
      _Fake(4, GameConstants.maxLevel),
    );
    expect(d.collect().single.resultLevel, isNull);
  });

  test('chain a–b–c–e of one level → a+b and c+e, b never reused', () {
    final a = _Fake(1, 1), b = _Fake(2, 1), c = _Fake(3, 1), e = _Fake(4, 1);
    d
      ..beginTouch(a, b)
      ..beginTouch(b, c)
      ..beginTouch(c, e);
    final pairs = d.collect();
    expect(pairs.map((p) => {p.a, p.b}), [
      {a, b},
      {c, e},
    ]);
  });
}
