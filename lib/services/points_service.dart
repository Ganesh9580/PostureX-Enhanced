/// Pure calculation logic for the reward points system — no storage here,
/// just the formulas. Persistence is handled separately by DatabaseService.
class PointsService {
  static const int unlockThreshold = 300;

  /// Points awarded for a single clean rep, scaled by its form-quality score
  /// (0–10). A perfect rep (score 10) earns 20 points; a mediocre rep (score
  /// 5) earns 10 points — rewards good form, not just doing the movement.
  static int pointsForRep(double score) {
    return (score * 2).round();
  }

  /// Flat bonus awarded for completing a full session (hitting the goal).
  /// Plank gets a higher bonus since it doesn't earn per-rep points along
  /// the way like squats/push-ups do.
  static int sessionBonus(bool isHoldBased) {
    return isHoldBased ? 40 : 20;
  }

  static bool crossesUnlockThreshold(int oldTotal, int newTotal) {
    return oldTotal < unlockThreshold && newTotal >= unlockThreshold;
  }
}