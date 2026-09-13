// lib/services/progress_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; 

/// One day's activity, for the Profile screen's weekly strip / monthly totals.
class DayActivity {
  final DateTime date;
  final int lessons;
  final int checkins;
  final int xp;
  const DayActivity({
    required this.date,
    required this.lessons,
    required this.checkins,
    required this.xp,
  });
}

class ProgressService {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLongestStreak = 'longest_streak';
  static const _kLastActive = 'last_active_date';
  static const _kActivity = 'daily_activity';
  static const _kDeviceId = 'device_id';

  // --- Unchanged from before ---

  Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final xp = (prefs.getInt(_kXp) ?? 0) + amount;
    await prefs.setInt(_kXp, xp);
    return xp;
  }

  Future<bool> completedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastKey = prefs.getString(_kLastActive);
    return lastKey == _dateKey(DateTime.now());
  }

  Future<int> getXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kXp) ?? 0;
  }

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStreak) ?? 0;
  }

  /// Same behavior as before (same-day no-op, consecutive +1, gap resets
  /// to 1) — only addition is longest-streak bookkeeping alongside it.
  Future<int> markTodayActive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final lastKey = prefs.getString(_kLastActive);
    int streak = prefs.getInt(_kStreak) ?? 0;

    if (lastKey == todayKey) return streak;

    if (lastKey != null) {
      final yesterday = today.subtract(const Duration(days: 1));
      streak = (lastKey == _dateKey(yesterday)) ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    await prefs.setInt(_kStreak, streak);
    await prefs.setString(_kLastActive, todayKey);

    final longest = prefs.getInt(_kLongestStreak) ?? 0;
    if (streak > longest) {
      await prefs.setInt(_kLongestStreak, streak);
    }

    return streak;
  }

  static String levelForXp(int xp) {
    if (xp < 50) return 'Novice';
    if (xp < 150) return 'Aware';
    if (xp < 300) return 'Sharp';
    return 'Guardian';
  }
/// Best-effort mirror to the real backend. Local storage already has the
/// numbers the UI shows — this just gives the event a durable, queryable
/// second home. A flaky network here must never surface to the user.
  Future<void> syncEventToBackend({required String type, required int xp}) async {
  try {
    final deviceId = await getDeviceId();
    await http
        .post(
          Uri.parse('${AppConfig.httpBase}/stats/event'),
          headers: {'Content-Type': 'application/json'},
          body: '{"device_id":"$deviceId","type":"$type","xp":$xp}',
        )
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Ignored on purpose.
  }
}

  // --- New for Home/Profile ---

  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLongestStreak) ?? 0;
  }

  /// Records one lesson- or check-in-completed event against today's date.
  /// Separate from addXp/markTodayActive (those own the running totals) —
  /// this only feeds the day-by-day breakdown for the Profile screen.
  Future<void> recordActivity({required String type, int xp = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadActivityMap(prefs);
    final key = _dateKey(DateTime.now());
    final entry = Map<String, int>.from(
      (map[key] ?? {'lessons': 0, 'checkins': 0, 'xp': 0})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
    entry['xp'] = (entry['xp'] ?? 0) + xp;
    if (type == 'lesson') {
      entry['lessons'] = (entry['lessons'] ?? 0) + 1;
    } else if (type == 'checkin') {
      entry['checkins'] = (entry['checkins'] ?? 0) + 1;
    }
    map[key] = entry;
    await prefs.setString(_kActivity, jsonEncode(map));
  }

  /// Last [n] days, oldest first, zero-filled for inactive days.
  Future<List<DayActivity>> getLastNDays(int n) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadActivityMap(prefs);
    final today = DateTime.now();
    final out = <DayActivity>[];
    for (int i = n - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final entry = map[_dateKey(d)] ?? const {'lessons': 0, 'checkins': 0, 'xp': 0};
      out.add(DayActivity(
        date: d,
        lessons: entry['lessons'] ?? 0,
        checkins: entry['checkins'] ?? 0,
        xp: entry['xp'] ?? 0,
      ));
    }
    return out;
  }

  /// Totals for the current calendar month.
  Future<Map<String, int>> getMonthSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadActivityMap(prefs);
    final now = DateTime.now();
    int lessons = 0, checkins = 0, xp = 0;
    map.forEach((key, entry) {
      final parts = key.split('-');
      if (parts.length == 3 &&
          int.tryParse(parts[0]) == now.year &&
          int.tryParse(parts[1]) == now.month) {
        lessons += entry['lessons'] ?? 0;
        checkins += entry['checkins'] ?? 0;
        xp += entry['xp'] ?? 0;
      }
    });
    return {'lessons': lessons, 'checkins': checkins, 'xp': xp};
  }

  Future<Map<String, Map<String, int>>> _loadActivityMap(SharedPreferences prefs) async {
    final raw = prefs.getString(_kActivity);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, (v2 as num).toInt()))),
    );
  }

  /// Stable per-device id, generated once, reused forever. Not tied to any
  /// login. Nothing reads this yet — it's what the DynamoDB swap will key
  /// stats rows on later tonight.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}