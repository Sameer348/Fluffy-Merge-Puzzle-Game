/// Decides when the jar has overflowed.
///
/// A settled creature poking above the danger line starts a countdown; if
/// the jar stays over the line for [limit] seconds, the run ends. Dipping
/// back below drains the timer quickly (not instantly), so a creature
/// bouncing on the line doesn't flicker the warning on and off, and a
/// brief bounce over it never ends a run.
class OverflowTimer {
  OverflowTimer({this.limit = 2.5, this.recoverRate = 2.0});

  /// Seconds over the line before game over.
  final double limit;

  /// How fast the timer drains when back under the line (× real time).
  final double recoverRate;

  double _over = 0;
  bool _fired = false;

  /// 0 = safe … 1 = game over.
  double get progress => (_over / limit).clamp(0.0, 1.0);

  /// Whole seconds left for the on-screen countdown (e.g. 3, 2, 1).
  int get secondsLeft => (limit - _over).ceil().clamp(0, limit.ceil());

  bool get isWarning => _over > 0 && !_fired;

  bool get hasFired => _fired;

  /// Advances the timer. Returns true exactly once: on the frame the jar
  /// overflows.
  bool update(double dt, {required bool overLine}) {
    if (_fired) return false;
    if (overLine) {
      _over += dt;
    } else {
      _over = (_over - dt * recoverRate).clamp(0.0, limit);
    }
    if (_over >= limit) {
      _fired = true;
      return true;
    }
    return false;
  }

  void reset() {
    _over = 0;
    _fired = false;
  }
}
