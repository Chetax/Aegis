// lib/screens/checkin_screen.dart
import 'package:app/services/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../services/checkin_socket_service.dart';
import '../services/progress_service.dart';
import '../model/checkin_frame.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/polly_tts_service.dart';
import '../config.dart';

enum CheckinPhase { idle, connecting, question, done, error }

/// A completed Q&A pair — one question the graph asked, the answer the user gave.
class QAExchange {
  final String question;
  final String answer;
  final bool isTeachBack;
  QAExchange({
    required this.question,
    required this.answer,
    required this.isTeachBack,
  });
}

class CheckinScreen extends StatefulWidget {
  final bool active;
  const CheckinScreen({super.key, required this.active});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
  
}

class _CheckinScreenState extends State<CheckinScreen> {
  late CheckinSocketService _service;
  final _inputController = TextEditingController();
  final _progress = ProgressService();
  final _speech = SpeechService();
  final _pollyTts = PollyTtsService(); 
  bool _speechReady = false;
  bool _isListening = false;
  String _sttLocale = 'en_US'; // 'en_US' | 'hi_IN'
  String get _sessionLanguage => _sttLocale == 'hi_IN' ? 'hi' : 'en';

  CheckinPhase _phase = CheckinPhase.idle;
  QuestionFrame? _currentQuestion;
  DoneFrame? _finalResult;
  String _errorText = '';
  final List<QAExchange> _history = [];
  String? _pendingAnswer;
   bool _hasConnected = false;

  @override
void initState() {
  super.initState();
  if (widget.active) {
    _connect();
    _hasConnected = true;
  }
  _speech.init().then((ok) {
    if (mounted) setState(() => _speechReady = ok);
  });
  _checkLocales();   // fire-and-forget, runs after init kicks off
  _loadLanguagePref();
}

  /// Re-reads the Profile language setting and applies it to STT/session
  /// language. NOT just called once in initState — CheckinScreen lives
  /// inside MainScaffold's IndexedStack, so it's created once and never
  /// rebuilt; without re-reading this here, a language change made in
  /// Profile after app launch would never reach an already-alive
  /// CheckinScreen until the whole app was restarted. Called again
  /// whenever the tab is (re)opened and whenever a new check-in starts,
  /// so it's always the CURRENT Profile setting, while still staying
  /// fixed for the duration of any one in-progress conversation (no
  /// toggle mid-flow).
  Future<void> _loadLanguagePref() async {
    final lang = await _progress.getLanguage();
    if (mounted) setState(() => _sttLocale = lang == 'hi' ? 'hi_IN' : 'en_US');
  }

Future<void> _checkLocales() async {
  final localeIds = await _speech.availableLocales();
  print('[speech] available locales: $localeIds');
}

  Future<void> _toggleMic() async {
  if (_isListening) {
    await _speech.stopListening();
    setState(() => _isListening = false);
    return;
  }
  setState(() => _isListening = true);
  await _speech.startListening(
    localeId: _sttLocale,
    onResult: (text, isFinal) {
      if (!_isListening) return;
      setState(() => _inputController.text = text);
      if (isFinal) setState(() => _isListening = false);
    },
  );
}

  void _connect() {
    _service = CheckinSocketService(AppConfig.wsBase, const Uuid().v4());
    _service.frames.listen(_onFrame);
  }

  @override
  void didUpdateWidget(covariant CheckinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Connect the first time the tab is actually opened — but never
    // disconnect on leaving, so an in-progress check-in isn't killed
    // if the user peeks at Home or Learn mid-flow.
    if (widget.active && !_hasConnected) {
      _connect();
      _hasConnected = true;
    }
    // Every time the user (re)opens this tab while idle (not mid-
    // conversation), pick up whatever language Profile currently says —
    // covers switching languages in Profile then coming back here.
    if (widget.active && !oldWidget.active && _phase == CheckinPhase.idle) {
      _loadLanguagePref();
    }
  }

  Future<void> _speakQuestion(QuestionFrame frame) async {
  await _pollyTts.speak(frame.text, language: _sessionLanguage);
}

  void _onFrame(CheckinFrame frame) {
    setState(() {
      switch (frame) {
        case QuestionFrame():
          _speech.stopListening(); 
          _isListening = false;     
          _commitPendingAnswer();
          _phase = CheckinPhase.question;
          _currentQuestion = frame;
          _inputController.clear();
          _speakQuestion(frame);
        case DoneFrame():
          _commitPendingAnswer();
          _phase = CheckinPhase.done;
          _finalResult = frame;
          _awardTeachBackXp(frame);
          _speakVerdict(frame); // fire-and-forget, runs once per frame
        case ErrorFrame():
          _phase = CheckinPhase.error;
          _errorText = frame.text;
      }
    });
  }

  /// XP for the teach-back understanding only — deliberately NOT for the
  /// check-in verdict itself. Check-In stays a serious tool, not a game.
  Future<void> _awardTeachBackXp(DoneFrame frame) async {
    final teachBack = frame.result['teach_back'] as Map<String, dynamic>?;
    if (teachBack == null) return;
    final grade = (teachBack['result'] ?? '').toString();
    final xpAward = switch (grade) {
      'correct' => 15,
      'partial' => 5,
      _ => 0,
    };
    if (xpAward > 0) {
      await _progress.addXp(xpAward);
      await _progress.recordActivity(type: 'checkin', xp: xpAward);
      _progress.syncEventToBackend(type: 'checkin', xp: xpAward); 
    }
  }

  /// Speaks the verdict aloud once the check-in reaches a result. For
/// high-risk verdicts, leads with a short, urgent spoken summary before
/// the full detail — reading 4+ sentences cold to someone mid-panic is
/// a lot; a short lead first matches how you'd actually talk to someone.
Future<void> _speakVerdict(DoneFrame frame) async {
  final risk = (frame.result['risk_level'] ?? 'low').toString().toLowerCase();
  final verdict = (frame.result['verdict_text'] ?? '').toString();
  if (verdict.isEmpty) return;

  final textToSpeak = risk == 'high'
      ? "Stop. Don't send money or share any information. $verdict"
      : verdict;

  await _pollyTts.speak(textToSpeak, language: _sessionLanguage);
}

  Future<void> _reportIt() async {
  final uri = Uri(scheme: 'tel', path: '1930');
  try {
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer. Call 1930 directly.')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer. Call 1930 directly.')),
      );
    }
  }
}

  void _commitPendingAnswer() {
    if (_currentQuestion != null && _pendingAnswer != null) {
      _history.add(QAExchange(
        question: _currentQuestion!.text,
        answer: _pendingAnswer!,
        isTeachBack: _currentQuestion!.field == 'user_explanation',
      ));
      _pendingAnswer = null;
    }
  }

  void _submitInitial() {
    if (_inputController.text.trim().isEmpty) return;
    _speech.stopListening(); 
    setState(() {
    _isListening = false;           
    _phase = CheckinPhase.connecting;
  });
    _service.start(_inputController.text.trim(), language: _sessionLanguage);
    _inputController.clear();
  }

  void _submitAnswer() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _speech.stopListening(); 
    setState(() => _isListening = false); 
    _pendingAnswer = text;
    _service.answer(text);
  }

  void _startNew() {
    _pollyTts.stop();
    _service.dispose();
    setState(() {
      _phase = CheckinPhase.idle;
      _currentQuestion = null;
      _finalResult = null;
      _errorText = '';
      _inputController.clear();
      _history.clear();
      _pendingAnswer = null;
    });
    _connect();
    // Pick up any Profile language change made since this conversation
    // started, before the next one begins.
    _loadLanguagePref();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _service.dispose();
    _speech.cancel(); 
    _pollyTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey(_phase),
                  child: _buildPhase(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case CheckinPhase.idle:
        return _buildIdle();
      case CheckinPhase.connecting:
        return _buildConnecting();
      case CheckinPhase.question:
        return _buildQuestion();
      case CheckinPhase.done:
        return _buildDone();
      case CheckinPhase.error:
        return _buildError();
    }
  }

  // ---------- IDLE ----------

    Widget _buildIdle() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Center(child: AegisLogo(size: 96)),
          const SizedBox(height: 12),
          const Center(
            child: StatusPill(
              label: 'SECURED CONNECTION',
              dotColor: AppColors.accent,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'What happened?',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe the call, message, or situation. I\'ll check it against known scam patterns.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLines: 6,
                  style: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Someone called saying they\'re from the police...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _speechReady ? _toggleMic : null,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? AppColors.riskHigh : AppColors.accent,
                ),
                tooltip: _speechReady ? 'Speak instead of typing' : 'Microphone unavailable',
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            onPressed: _submitInitial,
            label: 'Check This',
            icon: Icons.security,
          ),
          const SizedBox(height: 24),
        ]
            .animate(interval: 60.ms)
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0),
      );
}


  // ---------- CONNECTING ----------
  Widget _buildConnecting() {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.85,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AegisLogo(size: 88, showText: false)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2400.ms, curve: Curves.linear),
          const SizedBox(height: 32),
          Text(
            'Analyzing...',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking against known scam patterns',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 900.ms),
        ],
      ),
    );
  }

  // ---------- QUESTION ----------
  Widget _buildQuestion() {
  final isTeachBack = _currentQuestion!.field == 'user_explanation';
  final label = isTeachBack ? 'TEACH-BACK' : 'CLARIFICATION';
  final dotColor = isTeachBack ? AppColors.riskLow : AppColors.accent;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AegisLogo(size: 36, showText: false),
          StatusPill(label: label, dotColor: dotColor),
        ],
      ),
      const SizedBox(height: 20),
      if (_history.isNotEmpty) ...[
        ..._history.map((qa) => _buildHistoryItem(qa)),
        const SizedBox(height: 8),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 20),
      ],
      Text(
        _currentQuestion!.text,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Your answer...'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _speechReady ? _toggleMic : null,
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppColors.riskHigh : AppColors.accent,
            ),
            tooltip: _speechReady ? 'Speak instead of typing' : 'Microphone unavailable',
          ),
        ],
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        onPressed: _submitAnswer,
        label: 'Send',
        icon: Icons.arrow_forward,
      ),
      const SizedBox(height: 24),
    ]
        .animate(interval: 40.ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0),
  );
}

  Widget _buildHistoryItem(QAExchange qa) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  qa.question,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.subdirectory_arrow_right,
                    size: 14, color: AppColors.accentDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    qa.answer,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- DONE ----------
  Widget _buildDone() {
  final result = _finalResult!.result;
  final risk = (result['risk_level'] ?? 'low').toString();
  final verdict = (result['verdict_text'] ?? '').toString();
  final category = result['matched_category']?.toString();
  final teachBack = result['teach_back'] as Map<String, dynamic>?;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          AegisLogo(size: 36, showText: false),
          StatusPill(label: 'ANALYSIS COMPLETE', dotColor: AppColors.accent),
        ],
      ),
      const SizedBox(height: 28),
      RiskVerdictCard(
        riskLevel: risk,
        verdictText: verdict,
        matchedCategory: category,
      ),
      if (risk.toLowerCase() == 'high') ...[
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _reportIt,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.riskHigh.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.riskHigh.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call, color: AppColors.riskHigh, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Report It — Call 1930',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.riskHigh,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      if (teachBack != null) ...[
        const SizedBox(height: 20),
        _buildTeachBack(teachBack),
      ],
      const SizedBox(height: 24),
      GhostButton(onPressed: _startNew, label: 'New Check-In'),
      const SizedBox(height: 24),
    ],
  );
}

  /// Pure display — no side effects here. XP was already awarded once in
  /// `_awardTeachBackXp` when the DoneFrame first arrived (build methods
  /// can run many times and must stay side-effect-free).
  Widget _buildTeachBack(Map<String, dynamic> tb) {
    final grade = (tb['result'] ?? '').toString();
    final feedback = (tb['feedback'] ?? '').toString();
    final color = grade == 'correct'
        ? AppColors.riskLow
        : grade == 'partial'
            ? AppColors.riskMedium
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // BUG FIX: was a plain Row with an unbounded Text — "OFF_TRACK"
            // (longer than CORRECT/PARTIAL) plus letterSpacing pushed it
            // past the container width, causing a right-overflow banner.
            // Wrapping in Expanded lets it wrap to a second line instead.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.school_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your Understanding: ${grade.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ---------- ERROR ----------
  Widget _buildError() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.riskHigh),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: PrimaryButton(
              onPressed: _startNew,
              label: 'Try Again',
              icon: Icons.refresh,
            ),
          ),
        ],
      ),
    );
  }
}