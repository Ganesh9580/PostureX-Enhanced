/// Tracks the up/down phase of a rep-based exercise and detects when a
/// full repetition is complete, using frame-debouncing to filter out
/// jitter or small incidental movements — same technique validated in
/// the web prototype.
class RepDetector {
  final double downThreshold;   // angle below this = "down" phase
  final double upThreshold;     // angle above this = "up" phase
  final int framesToConfirm;    // consecutive frames required before confirming a transition

  String _state = "up"; // "up" or "down"
  int _downFrameCount = 0;
  int _upFrameCount = 0;
  double? _extremeAngle; // tracks the deepest point reached during "down" phase

  RepDetector({
    required this.downThreshold,
    required this.upThreshold,
    this.framesToConfirm = 5,
  });

  String get state => _state;
  double? get extremeAngle => _extremeAngle;

  /// Feed the current angle in on every frame. Returns true exactly once,
  /// on the frame a rep is confirmed complete (transitioned down then back up).
  bool update(double angle) {
    bool repCompleted = false;

    if (angle < downThreshold) {
      _downFrameCount++;
      _upFrameCount = 0;
    } else if (angle > upThreshold) {
      _upFrameCount++;
      _downFrameCount = 0;
    } else {
      _downFrameCount = 0;
      _upFrameCount = 0;
    }

    if (_state == "up" && _downFrameCount >= framesToConfirm) {
      _state = "down";
      _extremeAngle = null;
    } else if (_state == "down" && _upFrameCount >= framesToConfirm) {
      _state = "up";
      repCompleted = true;
    }

    if (_state == "down") {
      _extremeAngle = _extremeAngle == null
          ? angle
          : (angle < _extremeAngle! ? angle : _extremeAngle);
    }

    return repCompleted;
  }

  void reset() {
    _state = "up";
    _downFrameCount = 0;
    _upFrameCount = 0;
    _extremeAngle = null;
  }
}