// lib/model/daily_story.dart

/// One scene of the story = one comic-strip card.
class StoryScene {
  final String icon;
  final String text;
  StoryScene({required this.icon, required this.text});

  factory StoryScene.fromJson(Map<String, dynamic> j) => StoryScene(
        icon: j['icon'] as String? ?? 'alert',
        text: j['text'] as String? ?? '',
      );
}

class RedFlag {
  final String flag;
  final String explanation;
  RedFlag({required this.flag, required this.explanation});

  factory RedFlag.fromJson(Map<String, dynamic> j) => RedFlag(
        flag: j['flag'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
      );
}

class Quiz {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  Quiz({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        question: j['question'] as String? ?? '',
        options: (j['options'] as List?)?.cast<String>() ?? [],
        correctIndex: j['correct_index'] as int? ?? 0,
        explanation: j['explanation'] as String? ?? '',
      );
}

class DailyStory {
  final String title;
  final String category;
  final List<StoryScene> scenes;
  final List<RedFlag> redFlags;
  final Quiz quiz;
  final String? source;

  DailyStory({
    required this.title,
    required this.category,
    required this.scenes,
    required this.redFlags,
    required this.quiz,
    this.source,
  });

  factory DailyStory.fromJson(Map<String, dynamic> j) => DailyStory(
        title: j['title'] as String? ?? 'Today\'s Story',
        category: j['category'] as String? ?? '',
        scenes: (j['scenes'] as List? ?? [])
            .map((s) => StoryScene.fromJson(s as Map<String, dynamic>))
            .toList(),
        redFlags: (j['red_flags'] as List? ?? [])
            .map((r) => RedFlag.fromJson(r as Map<String, dynamic>))
            .toList(),
        quiz: Quiz.fromJson(j['quiz'] as Map<String, dynamic>? ?? {}),
        source: j['source'] as String?,
      );
}