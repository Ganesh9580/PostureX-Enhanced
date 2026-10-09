/// Jumping jacks don't reduce to a single joint angle like squats or
/// push-ups — instead this tracks two boolean conditions (arms raised,
/// legs spread) and detects the open→closed cycle, using the same
/// frame-debouncing principle as RepDetector to filter out jitter.
class JumpingJackDetector {
  final int framesToConfirm;
  String _state = "closed"; // "closed" (standing normally) or "open" (arms+legs out)
  int _openFrames = 0;
  int _closedFrames = 0;
  double _maxLegSpreadThisRep = 0;
  double _maxArmRaiseThisRep = 0;

  JumpingJackDetector({this.framesToConfirm = 4});

  String get state => _state;
  double get maxLegSpread => _maxLegSpreadThisRep;
  double get maxArmRaise => _maxArmRaiseThisRep;

  /// legSpreadRatio: ankle distance ÷ hip width (bigger = legs more apart)
  /// armRaiseAmount: how far above shoulder height the wrists are (bigger = arms higher)
  /// Returns true exactly once, the moment a full open→closed cycle completes.
  bool update({required bool armsUp, required bool legsApart, required double legSpreadRatio, required double armRaiseAmount}) {
    final isOpen = armsUp && legsApart;
    final isClosed = !armsUp && !legsApart;
    bool repCompleted = false;

    if (isOpen) {
      _openFrames++;
      _closedFrames = 0;
    } else if (isClosed) {
      _closedFrames++;
      _openFrames = 0;
    } else {
      _openFrames = 0;
      _closedFrames = 0;
    }

    if (_state == "open") {
      if (legSpreadRatio > _maxLegSpreadThisRep) _maxLegSpreadThisRep = legSpreadRatio;
      if (armRaiseAmount > _maxArmRaiseThisRep) _maxArmRaiseThisRep = armRaiseAmount;
    }

    if (_state == "closed" && _openFrames >= framesToConfirm) {
      _state = "open";
      _maxLegSpreadThisRep = 0;
      _maxArmRaiseThisRep = 0;
    } else if (_state == "open" && _closedFrames >= framesToConfirm) {
      _state = "closed";
      repCompleted = true;
    }

    return repCompleted;
  }

  void reset() {
    _state = "closed";
    _openFrames = 0;
    _closedFrames = 0;
    _maxLegSpreadThisRep = 0;
    _maxArmRaiseThisRep = 0;
  }
}