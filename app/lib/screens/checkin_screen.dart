// lib/screens/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../services/checkin_socket_service.dart';
import '../model/checkin_frame.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';

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
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  // Not `late final` — we reassign on "new check-in" to open a fresh socket.
  late CheckinSocketService _service;
  final _inputController = TextEditingController();

  CheckinPhase _phase = CheckinPhase.idle;
  QuestionFrame? _currentQuestion;
  DoneFrame? _finalResult;
  String _errorText = '';
    // History of completed Q&A pairs, oldest first.
  final List<QAExchange> _history = [];
  // The answer the user just sent — pending, waiting for the next frame to
  // confirm it "landed" so we can commit it to history.
  String? _pendingAnswer;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _service = CheckinSocketService('ws://10.0.2.2:8000', const Uuid().v4());
    _service.frames.listen(_onFrame);
  }

    void _onFrame(CheckinFrame frame) {
    setState(() {
      switch (frame) {
        case QuestionFrame():
          // If there was a previous question with a pending answer, commit
          // that pair to history before showing the new question.
          _commitPendingAnswer();
          _phase = CheckinPhase.question;
          _currentQuestion = frame;
          _inputController.clear();
        case DoneFrame():
          // Commit the last teach-back answer to history before showing done.
          _commitPendingAnswer();
          _phase = CheckinPhase.done;
          _finalResult = frame;
        case ErrorFrame():
          _phase = CheckinPhase.error;
          _errorText = frame.text;
      }
    });
  }

  /// If a question was on screen and the user answered it, push that pair
  /// into history. Called when the next frame arrives, confirming the graph
  /// accepted the answer.
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
    setState(() => _phase = CheckinPhase.connecting);
    _service.start(_inputController.text.trim());
    _inputController.clear();
  }

    void _submitAnswer() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _pendingAnswer = text;
    _service.answer(text);
  }

  void _startNew() {
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
  }

  @override
  void dispose() {
    _inputController.dispose();
    _service.dispose();
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
        TextField(
          controller: _inputController,
          maxLines: 6,
          style: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Someone called saying they\'re from the police...',
          ),
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

        // History of prior Q&A, if any — old ones dimmed so the current
        // question is what draws the eye.
        if (_history.isNotEmpty) ...[
          ..._history.map((qa) => _buildHistoryItem(qa)),
          const SizedBox(height: 8),
          // Divider between history and current question.
          Container(
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 20),
        ],

        // Current question — full brightness, larger type.
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
        TextField(
          controller: _inputController,
          maxLines: 4,
          style: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Your answer...'),
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

  /// One past Q&A pair, dimmed. Small type, muted colors — visible for
  /// context but not competing with the current question for attention.
  Widget _buildHistoryItem(QAExchange qa) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question — small, muted, monospace label prefix.
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
          // Answer — indented, slightly brighter to distinguish from question.
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
            children: [
              Icon(Icons.school_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Understanding: ${grade.toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 1.2,
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
          Icon(Icons.error_outline,
              size: 64, color: AppColors.riskHigh),
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