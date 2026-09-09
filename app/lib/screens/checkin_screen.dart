// lib/screens/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/checkin_socket_service.dart';
import '../model/checkin_frame.dart';

enum CheckinPhase { idle, connecting, question, done, error }

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  late final CheckinSocketService _service;
  final _inputController = TextEditingController();

  CheckinPhase _phase = CheckinPhase.idle;
  QuestionFrame? _currentQuestion;
  DoneFrame? _finalResult;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _service = CheckinSocketService('ws://10.0.2.2:8000', const Uuid().v4());
    _service.frames.listen(_onFrame);
  }

  void _onFrame(CheckinFrame frame) {
    setState(() {
      switch (frame) {
        case QuestionFrame():
          _phase = CheckinPhase.question;
          _currentQuestion = frame;
        case DoneFrame():
          _phase = CheckinPhase.done;
          _finalResult = frame;
        case ErrorFrame():
          _phase = CheckinPhase.error;
          _errorText = frame.text;
      }
    });
  }

  void _submitInitial() {
    setState(() => _phase = CheckinPhase.connecting);
    _service.start(_inputController.text);
    _inputController.clear();
  }

  void _submitAnswer() {
    _service.answer(_inputController.text);
    _inputController.clear();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_phase) {
            CheckinPhase.idle => _buildIdle(),
            CheckinPhase.connecting =>
              const Center(child: CircularProgressIndicator()),
            CheckinPhase.question => _buildQuestion(),
            CheckinPhase.done => _buildDone(),
            CheckinPhase.error => Center(
                child: Text(
                  _errorText,
                  style: const TextStyle(fontSize: 22, color: Colors.red),
                ),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Describe what happened',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inputController,
          maxLines: 4,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitInitial,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Check', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _currentQuestion!.text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inputController,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitAnswer,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Answer', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final risk = _finalResult!.result['risk_level'];
    final verdict = _finalResult!.result['verdict_text'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Risk: $risk', style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 12),
        Text(verdict, style: const TextStyle(fontSize: 20)),
      ],
    );
  }
}