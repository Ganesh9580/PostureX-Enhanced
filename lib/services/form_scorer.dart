/// Converts angle deviation from ideal form into a 0–10 score,
/// same formula validated in the web prototype.
class FormScorer {
  /// depthAngle: the deepest knee angle reached during the "down" phase
  /// backAngle: the back angle at the point of completing the rep
  static double scoreSquat({required double depthAngle, required double backAngle}) {
    // Ideal squat depth is around 90°. Score drops as it deviates.
    final depthScore = (10 - (90 - depthAngle).abs() / 6).clamp(0, 10);
    // Ideal back angle is straight (150°+). Score drops below that.
    final backScore = backAngle > 150 ? 10.0 : (10 - (150 - backAngle) / 4).clamp(0, 10);

    return ((depthScore + backScore) / 2 * 10).round() / 10; // round to 1 decimal
  }
}