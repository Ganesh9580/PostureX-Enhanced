import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Calculates the angle (in degrees) formed at point `b`, between the
/// lines b→a and b→c. This is the same 3-point angle math used in the
/// web prototype — e.g. for a knee angle: a=hip, b=knee, c=ankle.
class AngleCalculator {
  static double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abX = a.x - b.x;
    final abY = a.y - b.y;
    final cbX = c.x - b.x;
    final cbY = c.y - b.y;

    final dot = (abX * cbX) + (abY * cbY);
    final magAB = sqrt(abX * abX + abY * abY);
    final magCB = sqrt(cbX * cbX + cbY * cbY);

    if (magAB == 0 || magCB == 0) return 0;

    double cosAngle = dot / (magAB * magCB);
    // Clamp to avoid floating-point errors pushing this slightly outside [-1, 1]
    cosAngle = cosAngle.clamp(-1.0, 1.0);

    final angleRad = acos(cosAngle);
    return angleRad * 180 / pi;
  }

  /// Simple moving-average smoothing to reduce frame-to-frame jitter,
  /// same technique used in the web prototype.
  static double smooth(List<double> buffer, double newValue, {int maxSize = 5}) {
    buffer.add(newValue);
    if (buffer.length > maxSize) buffer.removeAt(0);
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }
}