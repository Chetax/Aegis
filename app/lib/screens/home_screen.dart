// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';
import 'profile_screen.dart';
import '../widgets/story_links_section.dart';

/// Landing tab. Greets the user, shows today's streak/XP at a glance,
/// and gives one-tap entry into Learn or Check-In — instead of forcing
/// a choice between calm-mode and panic-mode content on first open.
class HomeScreen extends StatefulWidget {
  final bool active;
  final void Function(int tabIndex) onNavigate;
  const HomeScreen({super.key, required this.active, required this.onNavigate});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  final _progress = ProgressService();
  int _streak = 0;
  int _xp = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await _progress.getStreak();
    final xp = await _progress.getXp();
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _xp = xp;
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _load();   // refresh every time the user returns to this tab
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridBackground(
      child: SafeArea(
        child: SingleChildScrollView(   
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AegisLogo(size: 36, showText: false),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined,
                        color: AppColors.textSecondary, size: 30),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _greeting,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 4),
              Text(
                "Here's where you stand today.",
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    )
                  : _StatsSummaryCard(streak: _streak, xp: _xp)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, end: 0),
              const SizedBox(height: 32),
              Text(
                'WHAT DO YOU WANT TO DO?',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                icon: Icons.menu_book_outlined,
                label: "Start Today's Lesson",
                onPressed: () => widget.onNavigate(1),
              ),
              const SizedBox(height: 14),
              GhostButton(
                onPressed: () => widget.onNavigate(2),
                label: 'Check Something Right Now',
              ),
              const SizedBox(height: 32),
              const StoryLinksSection(),
            ],
          ),
        ),
      ),
      )
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  final int streak;
  final int xp;
  const _StatsSummaryCard({required this.streak, required this.xp});

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
      child: Row(
        children: [
          _StatBlock(icon: Icons.local_fire_department, iconColor: Colors.orangeAccent, value: '$streak', label: 'day streak'),
          Container(width: 1, height: 40, color: AppColors.border),
          _StatBlock(icon: Icons.bolt, iconColor: AppColors.accent, value: '$xp', label: 'total XP'),
          Container(width: 1, height: 40, color: AppColors.border),
          _StatBlock(icon: Icons.shield, iconColor: AppColors.riskLow, value: level, label: 'level', isText: true),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isText;
  const _StatBlock({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: isText ? 15 : 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}