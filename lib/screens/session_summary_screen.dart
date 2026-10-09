import 'package:flutter/material.dart';

class SessionSummaryScreen extends StatelessWidget {
  final String title;
  final double resultValue;
  final bool isHoldBased;
  final double? avgScore;
  final int pointsEarned;
  final bool isPR;

  const SessionSummaryScreen({
    super.key,
    required this.title,
    required this.resultValue,
    required this.isHoldBased,
    this.avgScore,
    required this.pointsEarned,
    this.isPR = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedResult = isHoldBased
        ? "${resultValue.toStringAsFixed(1)} seconds"
        : "${resultValue.round()} reps";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text("Session Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            // Celebration Trophy Icon
            const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
            const SizedBox(height: 16),
            const Text(
              "Awesome Job!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "You successfully completed your $title session.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Performance Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161A21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: "Performance",
                    value: formattedResult,
                    valueColor: Colors.tealAccent,
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  if (avgScore != null) ...[
                    _SummaryRow(
                      label: "Average Form Score",
                      value: "${avgScore!.toStringAsFixed(1)} / 10",
                      valueColor: Colors.cyanAccent,
                    ),
                    const Divider(color: Colors.white12, height: 24),
                  ],
                  _SummaryRow(
                    label: "Points Earned",
                    value: "+$pointsEarned pts",
                    valueColor: Colors.amber,
                  ),
                  if (isPR) ...[
                    const Divider(color: Colors.white12, height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars, color: Colors.amber, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "New Personal Record!",
                            style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Return to Home",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
