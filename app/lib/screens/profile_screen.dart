// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _progress = ProgressService();
  bool _loading = true;
  int _xp = 0;
  int _streak = 0;
  int _longestStreak = 0;
  List<DayActivity> _week = [];
  Map<String, int> _month = {'lessons': 0, 'checkins': 0, 'xp': 0};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final xp = await _progress.getXp();
    final streak = await _progress.getStreak();
    final longest = await _progress.getLongestStreak();
    final week = await _progress.getLastNDays(7);
    final month = await _progress.getMonthSummary();
    if (!mounted) return;
    setState(() {
      _xp = xp;
      _streak = streak;
      _longestStreak = longest;
      _week = week;
      _month = month;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: GridBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        Text('Your Progress',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Center(child: AegisLogo(size: 56, showText: false)),
                    const SizedBox(height: 24),
                    _TotalsCard(xp: _xp, streak: _streak, longestStreak: _longestStreak)
                        .animate().fadeIn(duration: 350.ms),
                    const SizedBox(height: 28),
                    Text('LAST 7 DAYS',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _WeekStrip(days: _week).animate(delay: 150.ms).fadeIn(duration: 350.ms),
                    const SizedBox(height: 28),
                    Text('THIS MONTH',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _MonthSummaryCard(month: _month).animate(delay: 300.ms).fadeIn(duration: 350.ms),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final int xp;
  final int streak;
  final int longestStreak;
  const _TotalsCard({required this.xp, required this.streak, required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    final level = ProgressService.levelForXp(xp);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(level, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 4),
          Text('$xp XP total', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat(icon: Icons.local_fire_department, color: Colors.orangeAccent, value: '$streak', label: 'current streak'),
              _MiniStat(icon: Icons.emoji_events_outlined, color: AppColors.riskLow, value: '$longestStreak', label: 'longest streak'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<DayActivity> days;
  const _WeekStrip({required this.days});
  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        final active = d.lessons > 0 || d.checkins > 0;
        final isToday = _isSameDay(d.date, DateTime.now());
        return Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? AppColors.accent.withOpacity(0.18) : AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: isToday ? AppColors.accent : AppColors.border, width: isToday ? 2 : 1),
              ),
              child: Center(
                child: active
                    ? const Icon(Icons.check, color: AppColors.accent, size: 18)
                    : Text('${d.date.day}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 6),
            Text(_labels[d.date.weekday - 1], style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted)),
          ],
        );
      }).toList(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthSummaryCard extends StatelessWidget {
  final Map<String, int> month;
  const _MonthSummaryCard({required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MiniStat(icon: Icons.menu_book_outlined, color: AppColors.accent, value: '${month['lessons'] ?? 0}', label: 'lessons'),
          _MiniStat(icon: Icons.shield_outlined, color: AppColors.riskMedium, value: '${month['checkins'] ?? 0}', label: 'check-ins'),
          _MiniStat(icon: Icons.bolt, color: AppColors.riskLow, value: '${month['xp'] ?? 0}', label: 'xp earned'),
        ],
      ),
    );
  }
}