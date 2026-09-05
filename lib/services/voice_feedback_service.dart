import 'package:flutter_tts/flutter_tts.dart';

/// Wraps flutter_tts with the same throttling/interrupt behavior used in
/// the web prototype: newest cue always wins, but rapid-fire duplicate
/// speech is avoided.
class VoiceFeedbackService {
  final FlutterTts _tts = FlutterTts();
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastText = "";
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.48); // flutter_tts rate is 0.0–1.0, not WPM
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  Future<void> speak(String text, {bool force = false, int minGapMs = 1800}) async {
    if (!_ready || text.isEmpty) return;
    final now = DateTime.now();
    final gap = now.difference(_lastSpokenAt).inMilliseconds;

    if (!force && (gap < minGapMs || text == _lastText)) return;

    _lastSpokenAt = now;
    _lastText = text;
    await _tts.stop(); // interrupt whatever was playing with the newest cue
    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}