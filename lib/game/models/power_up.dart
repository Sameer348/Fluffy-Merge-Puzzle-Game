/// The four power-ups.
enum PowerUp {
  /// Clears the smallest creatures (destructive → confirm).
  sweep('Sweep', needsTarget: false, destructive: true),

  /// Removes one chosen creature (destructive → confirm).
  pop('Pop', needsTarget: true, destructive: true),

  /// Upgrades one chosen creature by a level.
  grow('Grow', needsTarget: true, destructive: false),

  /// Shakes the jar to loosen and spread a crowded pile.
  shake('Shake', needsTarget: false, destructive: false);

  const PowerUp(
    this.label, {
    required this.needsTarget,
    required this.destructive,
  });

  final String label;

  /// The player must tap a creature first (POP, GROW).
  final bool needsTarget;

  /// Removes creatures, so the player confirms before it happens.
  final bool destructive;
}
