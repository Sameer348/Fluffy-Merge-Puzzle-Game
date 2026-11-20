import 'package:flame/components.dart';

/// Emitted once per completed merge. Score/combo (Phase 7), particles
/// (Phase 8), audio/haptics (Phase 15) and analytics all subscribe to this
/// instead of reaching into the physics code.
class MergeEvent {
  const MergeEvent({
    required this.fromLevel,
    required this.resultLevel,
    required this.position,
    required this.time,
    required this.createdId,
  });

  /// Level of the two creatures that merged.
  final int fromLevel;

  /// Level of the new creature, or null for a max-level clear (two Rainbow
  /// Puffs pop in a burst and nothing is created).
  final int? resultLevel;

  /// Where it happened, in world units (jar meters).
  final Vector2 position;

  /// Game clock in seconds when it happened (for combo windows).
  final double time;

  /// Id of the creature that was created, or null for a max-level clear.
  final int? createdId;

  bool get isMaxClear => resultLevel == null;

  @override
  String toString() =>
      'MergeEvent(L$fromLevel → ${resultLevel ?? 'CLEAR'} @ ${time.toStringAsFixed(2)}s)';
}
