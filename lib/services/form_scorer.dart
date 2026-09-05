/// Converts angle deviation from ideal form into a 0–10 score,
/// same formula validated in the web prototype.
class FormScorer {
  /// depthAngle: the deepest knee angle reached during the "down" phase
  /// backAngle: the back angle at the point of completing the rep
  static double scoreSquat({required double depthAngle, required double backAngle}) {
    final depthScore = (10 - (90 - depthAngle).abs() / 6).clamp(0, 10);
    final backScore = backAngle > 150 ? 10.0 : (10 - (150 - backAngle) / 4).clamp(0, 10);
    return ((depthScore + backScore) / 2 * 10).round() / 10;
  }

  /// depthAngle: the smallest elbow angle reached during the "down" phase
  /// bodyLineAngle: the body-line (shoulder-hip-ankle) angle at that point —
  /// checks the body stayed straight instead of sagging.
  static double scorePushup({required double depthAngle, required double bodyLineAngle}) {
    final depthScore = (10 - (75 - depthAngle).abs() / 5).clamp(0, 10);
    final bodyScore = bodyLineAngle > 160 ? 10.0 : (10 - (160 - bodyLineAngle) / 3).clamp(0, 10);
    return ((depthScore + bodyScore) / 2 * 10).round() / 10;
  }
}