import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastActive = 'last_active_date';

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

  /// Call once when the user finishes today's lesson (quiz complete).
  /// Handles: same day again (no change), consecutive day (+1),
  /// gap of 2+ days (reset to 1).
  Future<int> markTodayActive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final lastKey = prefs.getString(_kLastActive);
    int streak = prefs.getInt(_kStreak) ?? 0;

    if (lastKey == todayKey) return streak; // already counted today

    if (lastKey != null) {
      final yesterday = today.subtract(const Duration(days: 1));
      streak = (lastKey == _dateKey(yesterday)) ? streak + 1 : 1;
    } else {
      streak = 1; // first lesson ever
    }

    await prefs.setInt(_kStreak, streak);
    await prefs.setString(_kLastActive, todayKey);
    return streak;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String levelForXp(int xp) {
    if (xp < 50) return 'Novice';
    if (xp < 150) return 'Aware';
    if (xp < 300) return 'Sharp';
    return 'Guardian';
  }
}