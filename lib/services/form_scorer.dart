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

  /// legSpreadRatio: peak ankle-distance ÷ hip-width reached during the rep
  /// (ideal ~2.0, meaning legs spread to about twice hip width)
  /// armRaiseAmount: peak wrist-above-shoulder distance (normalized landmark
  /// units) reached during the rep (ideal ~0.15)
  static double scoreJumpingJack({required double legSpreadRatio, required double armRaiseAmount}) {
    final legScore = (10 - (2.0 - legSpreadRatio).abs() * 8).clamp(0, 10);
    final armScore = (armRaiseAmount / 0.15 * 10).clamp(0, 10);
    return ((legScore + armScore) / 2 * 10).round() / 10;
  }

  /// Jump squats reuse the squat depth/back scoring, since the movement
  /// pattern is the same — only the addition of a jump is new.
  static double scoreJumpSquat({required double depthAngle, required double backAngle}) {
    return scoreSquat(depthAngle: depthAngle, backAngle: backAngle);
  }
}