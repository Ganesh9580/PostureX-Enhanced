/// Tracks a hold-based exercise (like plank) where the goal is sustained
/// correct form over time, not discrete repetitions. Counts up only while
/// form is good, pauses (does not reset) when form breaks, and resumes
/// when form is corrected — same behavior validated in the web prototype.
class HoldTimer {
  double _heldSeconds = 0;
  DateTime? _lastTickTime;
  bool _wasInGoodForm = false;

  double get heldSeconds => _heldSeconds;
  bool get wasInGoodForm => _wasInGoodForm;

  /// Call this every frame with whether form is currently good.
  /// Returns true exactly once, the moment the hold time crosses the goal.
  bool update(bool isGoodForm, double goalSeconds) {
    final now = DateTime.now();
    bool justReachedGoal = false;

    if (_lastTickTime == null) {
      _lastTickTime = now;
      _wasInGoodForm = isGoodForm;
      return false;
    }

    double dt = now.difference(_lastTickTime!).inMilliseconds / 1000.0;
    // Cap the per-frame time delta — prevents a large "jump" in held time
    // if tracking was briefly lost and reacquired after a gap (a real bug
    // found and fixed in the web prototype).
    if (dt > 0.2) dt = 0.2;
    _lastTickTime = now;

    final wasAlreadyPastGoal = _heldSeconds >= goalSeconds;

    if (isGoodForm) {
      _heldSeconds += dt;
      _wasInGoodForm = true;
    } else {
      _wasInGoodForm = false;
    }

    if (!wasAlreadyPastGoal && _heldSeconds >= goalSeconds) {
      justReachedGoal = true;
    }

    return justReachedGoal;
  }

  void reset() {
    _heldSeconds = 0;
    _lastTickTime = null;
    _wasInGoodForm = false;
  }
}