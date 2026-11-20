import '../../core/constants/game_constants.dart';

/// What the detector needs to know about a creature. Kept abstract so the
/// detector is pure Dart and unit-testable without physics.
abstract interface class MergeCandidate {
  /// Unique, increasing id (spawn order).
  int get id;

  /// Current creature level (1-based).
  int get level;

  /// False once removed from the jar or already claimed by a merge.
  bool get canMerge;

  /// Set by the detector when this creature is handed out in a merge pair,
  /// so it can never take part in a second merge.
  set claimedForMerge(bool value);
}

/// Two touching creatures of the same level, ready to merge.
class MergePair<T extends MergeCandidate> {
  const MergePair(this.a, this.b);

  /// [a] is the creature that has been in the jar longer (lower id).
  final T a;
  final T b;

  int get level => a.level;

  /// The level the merge produces, or null when two max-level creatures
  /// meet (Phase 6 turns that into a special "clear" burst).
  int? get resultLevel => level < GameConstants.maxLevel ? level + 1 : null;

  @override
  String toString() => 'MergePair(#${a.id} + #${b.id}, L$level)';
}

/// Tracks which creatures are touching and hands out same-level merges.
///
/// How it works:
/// * Box2D begin/end touch events maintain a set of touching pairs. Pairs
///   stay in the set while bodies sleep (no end event), so a level change
///   on a resting creature (e.g. GROW) is still noticed.
/// * Levels are compared in [collect], not when contact begins, for the same
///   reason.
/// * [collect] is called once per frame *after* the physics step (bodies
///   must not be created or destroyed during a step). It walks pairs in the
///   order they started touching ("first touch merges first"), claims both
///   creatures, and skips any pair whose creature is already claimed. That
///   guarantees no creature is ever in two merges and every pair is emitted
///   at most once.
/// * Iteration order is deterministic, so replays and daily challenges
///   resolve chains the same way every time.
class MergeDetector<T extends MergeCandidate> {
  /// Touching pairs keyed by (lowId, highId) → touch order.
  final Map<(int, int), _Touch<T>> _touching = {};
  int _seq = 0;

  int get touchingPairCount => _touching.length;

  static (int, int) _key(MergeCandidate a, MergeCandidate b) =>
      a.id < b.id ? (a.id, b.id) : (b.id, a.id);

  void beginTouch(T a, T b) {
    if (identical(a, b)) return;
    _touching.putIfAbsent(_key(a, b), () {
      final (lo, hi) = a.id < b.id ? (a, b) : (b, a);
      return _Touch(lo, hi, _seq++);
    });
  }

  void endTouch(T a, T b) => _touching.remove(_key(a, b));

  /// Drops every pair involving [c] (call when a creature leaves the jar;
  /// Box2D doesn't reliably report end-touch for destroyed bodies).
  void forget(T c) =>
      _touching.removeWhere((_, t) => identical(t.a, c) || identical(t.b, c));

  void clear() => _touching.clear();

  /// Returns this frame's merges: same level, both mergeable, no creature
  /// used twice. Claimed pairs are removed from tracking.
  List<MergePair<T>> collect() {
    if (_touching.isEmpty) return const [];
    final ready = <_Touch<T>>[];
    final stale = <(int, int)>[];
    _touching.forEach((key, t) {
      if (!t.a.canMerge || !t.b.canMerge) {
        // A removed creature may linger until forget(); claimed ones are
        // about to be removed anyway.
        stale.add(key);
      } else if (t.a.level == t.b.level) {
        ready.add(t);
      }
    });
    for (final k in stale) {
      _touching.remove(k);
    }
    if (ready.isEmpty) return const [];

    ready.sort((x, y) => x.seq.compareTo(y.seq));
    final result = <MergePair<T>>[];
    final used = <int>{};
    for (final t in ready) {
      if (used.contains(t.a.id) || used.contains(t.b.id)) continue;
      used
        ..add(t.a.id)
        ..add(t.b.id);
      t.a.claimedForMerge = true;
      t.b.claimedForMerge = true;
      _touching.remove(_key(t.a, t.b));
      result.add(MergePair(t.a, t.b));
    }
    return result;
  }
}

class _Touch<T> {
  _Touch(this.a, this.b, this.seq);
  final T a;
  final T b;
  final int seq;
}
