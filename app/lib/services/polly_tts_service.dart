// lib/services/polly_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads Polly-synthesized speech from the backend and plays it.
/// Narration is an enhancement — every failure here is swallowed, never
/// surfaced to the user, matching the fail-soft pattern used everywhere
/// else in this app.
class PollyTtsService {
  static const _backendBase = 'http://10.0.2.2:8000';
  final AudioPlayer _player = AudioPlayer();
  int _requestSeq = 0;

  Future<void> speak(String text, {String language = 'en'}) async {
    final seq = ++_requestSeq;
    await stop();
    try {
      final resp = await http
          .post(
            Uri.parse('$_backendBase/tts/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(const Duration(seconds: 15));

      if (seq != _requestSeq) return; // a newer speak() call superseded this one

      if (resp.statusCode != 200) {
        print('PollyTtsService: backend returned ${resp.statusCode}');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aegis_tts_current.mp3');
      await file.writeAsBytes(resp.bodyBytes);

      if (seq != _requestSeq) return; // stale response, don't play it

      await _player.setFilePath(file.path);
      await _player.play();
    } catch (e) {
      print('PollyTtsService error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}