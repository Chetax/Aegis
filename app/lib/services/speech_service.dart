import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thin wrapper around device STT. One instance can be reused across
/// the whole check-in — start/stop as many times as needed.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  /// Call once (e.g. in initState) — requests the runtime permission
  /// the first time it's called on a fresh install.
  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (e) => print('[speech] error: $e'),
      onStatus: (s) => print('[speech] status: $s'),
    );
    return _available;
    
  }

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<List<String>> availableLocales() async {
  final locales = await _speech.locales();
  return locales.map((l) => l.localeId).toList();
}

  Future<void> startListening({
  required void Function(String text, bool isFinal) onResult,
  String localeId = 'en_US',
}) async {
  _available = await _speech.initialize(
    onError: (e) => print('[speech] error: $e'),
    onStatus: (s) => print('[speech] status: $s'),
  );
  if (!_available) return;
  await _speech.listen(
    onResult: (r) {
      print('[speech] result: "${r.recognizedWords}" final=${r.finalResult}');
      onResult(r.recognizedWords, r.finalResult);
    },
    localeId: localeId,
    listenFor: const Duration(minutes: 3),
    pauseFor: const Duration(seconds: 20),
    partialResults: true,
  );
}

  Future<void> stopListening() => _speech.stop();
  void cancel() => _speech.cancel();
}