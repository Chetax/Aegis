// lib/screens/learn_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/polly_tts_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/daily_story.dart';
import '../services/story_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';

enum LearnPhase { loading, story, flags, quiz, complete, error }

class LearnScreen extends StatefulWidget {
  final bool active;
  const LearnScreen({super.key, required this.active});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _service = StoryService();
  final _tts = PollyTtsService();
  final _progress = ProgressService();

  LearnPhase _phase = LearnPhase.loading;
  DailyStory? _story;
  String _errorText = '';
  int _currentScene = 0;
  int? _selectedAnswer;
  bool _quizSubmitted = false;

  // Progress state — loaded once, updated as XP/streak events happen.
  int _streak = 0;
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _load();
  }

  Future<void> _loadProgress() async {
    final streak = await _progress.getStreak();
    final xp = await _progress.getXp();
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _xp = xp;
    });
  }

  Future<void> _load() async {
    try {
      final story = await _service.fetchDaily();
      setState(() {
        _story = story;
        _phase = LearnPhase.story;
      });
      Future.delayed(const Duration(milliseconds: 600), _speakCurrentScene);
    } catch (e) {
      setState(() {
        _phase = LearnPhase.error;
        _errorText = 'Couldn\'t load today\'s story. $e';
      });
    }
  }


  Future<void> _speakCurrentScene() async {
  if (!widget.active) return;
  if (_story == null) return;
  await _tts.speak(_story!.scenes[_currentScene].text, language: 'en');
}

  void _nextScene() {
    if (_story == null) return;
    if (_currentScene < _story!.scenes.length - 1) {
      setState(() => _currentScene++);
      _speakCurrentScene();
    } else {
      _tts.stop();
      setState(() => _phase = LearnPhase.flags);
    }
  }

  void _goToQuiz() {
    setState(() => _phase = LearnPhase.quiz);
  }

  /// Marks the quiz submitted, shows correct/wrong styling, and awards XP
  /// for attempting the quiz (more for correct, a little for trying).
  Future<void> _submitQuiz() async {
    if (_selectedAnswer == null) return;
    setState(() => _quizSubmitted = true);
  }

  /// Called when the user finishes the whole lesson. Awards the
  /// completion bonus and updates the streak, then moves to the
  /// complete screen.
  Future<void> _finish() async {
    if (!await _progress.completedToday()) {
      final isCorrect = _selectedAnswer == _story!.quiz.correctIndex;
      final awarded = isCorrect ? 25 : 15;
      await _progress.addXp(awarded);                              
      await _progress.recordActivity(type: 'lesson', xp: awarded);
      _progress.syncEventToBackend(type: 'lesson', xp: awarded);
      await _progress.markTodayActive();
    }
    
    // ALWAYS fetch the latest totals, even on a replay
    final xp = await _progress.getXp();
    final currentStreak = await _progress.getStreak();
    
    if (!mounted) return;
    setState(() {
      _xp = xp;
      _streak = currentStreak; // This ensures the UI updates to the correct number
      _phase = LearnPhase.complete;
    });
  }

  @override
  void didUpdateWidget(covariant LearnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _tts.stop();
    } else if (!oldWidget.active && widget.active && _phase == LearnPhase.story) {
      _speakCurrentScene();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: _buildPhase(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case LearnPhase.loading:
        return _buildLoading();
      case LearnPhase.story:
        return _buildStory();
      case LearnPhase.flags:
        return _buildFlags();
      case LearnPhase.quiz:
        return _buildQuiz();
      case LearnPhase.complete:
        return _buildComplete();
      case LearnPhase.error:
        return _buildError();
    }
  }

  // ---------- LOADING ----------
  Widget _buildLoading() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AegisLogo(size: 72, showText: false)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2400.ms),
          const SizedBox(height: 24),
          Text(
            'Preparing today\'s lesson...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- STORY (comic strip) ----------
  Widget _buildStory() {
    final scene = _story!.scenes[_currentScene];
    final isLast = _currentScene == _story!.scenes.length - 1;

    return SingleChildScrollView(
      child:Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('TODAY\'S STORY'),
        const SizedBox(height: 20),
        Text(
          _story!.title,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Scene ${_currentScene + 1} of ${_story!.scenes.length}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        KeyedSubtree(
          key: ValueKey(_currentScene),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(_iconFor(scene.icon),
                      size: 44, color: AppColors.accent),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms),
                const SizedBox(height: 24),
                Text(
                  scene.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _speakCurrentScene,
                  icon: const Icon(Icons.volume_up,
                      size: 18, color: AppColors.accent),
                  label: Text(
                    'Read aloud',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideX(begin: 0.15, end: 0, curve: Curves.easeOut),
        ),
        const SizedBox(height: 24),
        if (_currentScene > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() => _currentScene--);
                _speakCurrentScene();
              },
              icon: const Icon(Icons.arrow_back,
                  size: 16, color: AppColors.textSecondary),
              label: Text(
                'Previous scene',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_story!.scenes.length, (i) {
            final active = i == _currentScene;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() => _currentScene = i);
                  _speakCurrentScene();
                },
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: active ? 24 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          onPressed: _nextScene,
          label: isLast ? 'See the Red Flags' : 'Next',
          icon: isLast ? Icons.flag : Icons.arrow_forward,
        ),
      ],
   ));
  }

  // ---------- RED FLAGS ----------
  Widget _buildFlags() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _phase = LearnPhase.story;
                  _currentScene = _story!.scenes.length - 1;
                });
              },
              icon: const Icon(Icons.arrow_back,
                  size: 16, color: AppColors.textSecondary),
              label: Text(
                'Back to story',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          _buildHeader('WHAT GAVE IT AWAY'),
          const SizedBox(height: 20),
          Text(
            '${_story!.redFlags.length} red flags in that story',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Learn to spot these anywhere.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ..._story!.redFlags.asMap().entries.map((e) {
            final i = e.key;
            final flag = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.riskHigh.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.riskHigh.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.riskHigh,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flag.flag,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            flag.explanation,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (i * 120).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.15, end: 0),
            );
          }),
          const SizedBox(height: 20),
          PrimaryButton(
            onPressed: _goToQuiz,
            label: 'Test Yourself',
            icon: Icons.psychology,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------- QUIZ ----------
  Widget _buildQuiz() {
    final q = _story!.quiz;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _phase = LearnPhase.flags;
                  _selectedAnswer = null;
                  _quizSubmitted = false;
                });
              },
              icon: const Icon(Icons.arrow_back,
                  size: 16, color: AppColors.textSecondary),
              label: Text(
                'Back to red flags',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          _buildHeader('QUICK CHECK'),
          const SizedBox(height: 20),
          Text(
            q.question,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          ...q.options.asMap().entries.map((e) {
            final i = e.key;
            final option = e.value;
            final isSelected = _selectedAnswer == i;
            final isCorrect = i == q.correctIndex;

            Color borderColor = AppColors.border;
            Color bgColor = AppColors.bgSurface;
            IconData? trailingIcon;

            if (_quizSubmitted) {
              if (isCorrect) {
                borderColor = AppColors.riskLow;
                bgColor = AppColors.riskLow.withOpacity(0.1);
                trailingIcon = Icons.check_circle;
              } else if (isSelected) {
                borderColor = AppColors.riskHigh;
                bgColor = AppColors.riskHigh.withOpacity(0.1);
                trailingIcon = Icons.cancel;
              }
            } else if (isSelected) {
              borderColor = AppColors.accent;
              bgColor = AppColors.bgRaised;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _quizSubmitted
                    ? null
                    : () => setState(() => _selectedAnswer = i),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (trailingIcon != null)
                        Icon(trailingIcon,
                            color: isCorrect
                                ? AppColors.riskLow
                                : AppColors.riskHigh),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_quizSubmitted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.explanation,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms),
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: _finish,
              label: 'Complete Lesson',
              icon: Icons.check,
            ),
          ] else ...[
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: _selectedAnswer == null ? null : _submitQuiz,
              label: 'Check Answer',
              icon: Icons.arrow_forward,
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------- COMPLETE ----------
  Widget _buildComplete() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.riskLow.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.riskLow.withOpacity(0.5), width: 3),
            ),
            child: const Icon(Icons.check_circle,
                size: 72, color: AppColors.riskLow),
          ).animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 28),
          Text(
            'Lesson complete',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 10),
          Text(
            'You\'re a little harder to scam today.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ).animate(delay: 500.ms).fadeIn(),
          const SizedBox(height: 14),
          Text(
            '🔥 $_streak day streak  ·  $_xp XP total',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ).animate(delay: 600.ms).fadeIn(),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: const StatusPill(
              label: 'NEW LESSON TOMORROW',
              dotColor: AppColors.accent,
            ),
          ).animate(delay: 700.ms).fadeIn(),
        ],
      ),
    );
  }

  // ---------- ERROR ----------
  Widget _buildError() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load today\'s story',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: PrimaryButton(
              onPressed: () {
                setState(() => _phase = LearnPhase.loading);
                _load();
              },
              label: 'Try Again',
              icon: Icons.refresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AegisLogo(size: 32, showText: false),
            StatusPill(label: label, dotColor: AppColors.accent),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ProgressBadge(streak: _streak, xp: _xp),
        ),
      ],
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'phone':
        return Icons.phone_in_talk;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'money':
        return Icons.attach_money;
      case 'shield':
        return Icons.shield;
      case 'person':
        return Icons.person;
      case 'document':
        return Icons.description;
      default:
        return Icons.info_outline;
    }
  }
}