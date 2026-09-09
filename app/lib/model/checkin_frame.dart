// lib/models/checkin_frame.dart

/// A closed set of possible server frames. Every subtype below IS a
/// CheckinFrame — this is what "sealed" buys you: the compiler knows
/// these three are the ONLY possibilities, so later, a switch statement
/// over a CheckinFrame can be checked exhaustively (miss a case, compiler
/// yells at you — same safety enum gives you for fixed labels).
sealed class CheckinFrame {
  /// Turns a raw decoded Map (from CheckinSocketService.frames) into the
  /// right subtype, based on the "type" key.
  factory CheckinFrame.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'question':
        return QuestionFrame(
          field: json['field'],
          text: json['text'],
        );
      case 'done':
        return DoneFrame(
          result: json['result'],
        );
      case 'error':
        return ErrorFrame(
          text: json['text'],
        );
      default:
        throw Exception('Unknown frame type: ${json['type']}');
    }
  }
}

class QuestionFrame implements CheckinFrame {
  final String field;
  final String text;
  QuestionFrame({required this.field, required this.text});
}

class DoneFrame implements CheckinFrame {
  final Map<String, dynamic> result;
  DoneFrame({required this.result});
}

class ErrorFrame implements CheckinFrame {
  final String text;
  ErrorFrame({required this.text});
}