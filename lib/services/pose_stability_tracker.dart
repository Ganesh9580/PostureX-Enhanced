import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Class tracking frame-to-frame coordinate stability for static yoga and hold poses.
class PoseStabilityTracker {
  final int windowSize;
  final double varianceThreshold;

  final List<double> _xBuffer = [];
  final List<double> _yBuffer = [];

  PoseStabilityTracker({
    this.windowSize = 10,
    this.varianceThreshold = 0.0025,
  });

  /// Updates the buffer with the key landmark position and returns current stability score (0.0 = shaky, 1.0 = rock solid).
  double update(PoseLandmark landmark) {
    _xBuffer.add(landmark.x);
    _yBuffer.add(landmark.y);

    if (_xBuffer.length > windowSize) {
      _xBuffer.removeAt(0);
      _yBuffer.removeAt(0);
    }

    if (_xBuffer.length < windowSize) return 1.0;

    final varX = _calculateVariance(_xBuffer);
    final varY = _calculateVariance(_yBuffer);
    final totalVar = varX + varY;

    // Convert variance to 0.0-1.0 stability score
    final score = (1.0 - (totalVar / varianceThreshold)).clamp(0.0, 1.0);
    return score;
  }

  bool isStable(double score) => score >= 0.50;

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSqDiff = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
    return sumSqDiff / values.length;
  }

  void reset() {
    _xBuffer.clear();
    _yBuffer.clear();
  }
}
