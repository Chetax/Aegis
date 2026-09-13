// lib/services/story_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/daily_story.dart';
import '../config.dart';

class StoryService {
  // Same emulator-host mapping as the WebSocket.

  Future<DailyStory> fetchDaily() async {
    final resp = await http.get(Uri.parse('${AppConfig.httpBase}/story/daily'));
    if (resp.statusCode != 200) {
      throw Exception('Story fetch failed: ${resp.statusCode}');
    }
    final decoded = json.decode(resp.body) as Map<String, dynamic>;
    return DailyStory.fromJson(decoded);
  }
}