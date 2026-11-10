import 'lesson_activity_model.dart';

class LessonQuizQuestionModel {
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final String feedback;

  const LessonQuizQuestionModel({
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    this.feedback = '',
  });

  factory LessonQuizQuestionModel.fromMap(Map<String, dynamic> map) {
    return LessonQuizQuestionModel(
      prompt: (map['prompt'] ?? '').toString(),
      options: (map['options'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      correctAnswer: (map['correctAnswer'] ?? '').toString(),
      feedback: (map['feedback'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'prompt': prompt,
        'options': options,
        'correctAnswer': correctAnswer,
        'feedback': feedback,
      };

  bool get isValid =>
      prompt.trim().isNotEmpty &&
      options.length >= 2 &&
      options.contains(correctAnswer);
}

/// Represents a single lesson document from the `lessons` collection.
/// `signIds` replaces the ERD's LessonSigns join table - Firestore has no
/// joins, so the related sign IDs are embedded directly as an array field.
/// See Firestore_Schema.docx section 2 for the rationale.
class LessonModel {
  final String id;
  final String title;
  final String category;
  final String videoUrl;
  final String imageUrl;
  final String description;
  final List<String> signIds;
  final List<LessonActivityModel> activities;
  final List<String> learningObjectives;
  final List<LessonQuizQuestionModel> quizQuestions;
  final List<String> sourceReferences;
  final String contentValidationStatus;
  final String mediaStatus;

  LessonModel({
    required this.id,
    required this.title,
    required this.category,
    required this.videoUrl,
    this.imageUrl = '',
    required this.description,
    required this.signIds,
    this.activities = const [],
    this.learningObjectives = const [],
    this.quizQuestions = const [],
    this.sourceReferences = const [],
    this.contentValidationStatus = '',
    this.mediaStatus = '',
  });

  factory LessonModel.fromMap(String id, Map<String, dynamic> map) {
    return LessonModel(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      description: map['description'] ?? '',
      signIds: List<String>.from(map['signIds'] ?? []),
      activities: _parseActivities(map['activities']),
      learningObjectives: _stringList(map['learningObjectives']),
      quizQuestions: _parseQuizQuestions(map['quizQuestions']),
      sourceReferences: _stringList(map['sourceReferences']),
      contentValidationStatus: (map['contentValidationStatus'] ?? '').toString(),
      mediaStatus: (map['mediaStatus'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'title': title,
      'category': category,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'description': description,
      'signIds': signIds,
    };
    if (activities.isNotEmpty) {
      data['activities'] = activities.map(_activityToMap).toList();
    }
    if (learningObjectives.isNotEmpty) {
      data['learningObjectives'] = learningObjectives;
    }
    if (quizQuestions.isNotEmpty) {
      data['quizQuestions'] = quizQuestions.map((question) => question.toMap()).toList();
    }
    if (sourceReferences.isNotEmpty) data['sourceReferences'] = sourceReferences;
    if (contentValidationStatus.isNotEmpty) {
      data['contentValidationStatus'] = contentValidationStatus;
    }
    if (mediaStatus.isNotEmpty) data['mediaStatus'] = mediaStatus;
    return data;
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static List<LessonActivityModel> _parseActivities(dynamic raw) {
    if (raw is! List) return const [];
    final activities = <LessonActivityModel>[];
    for (var index = 0; index < raw.length; index++) {
      try {
        final map = Map<String, dynamic>.from(raw[index] as Map);
        activities.add(LessonActivityModel.fromMap('activity_$index', map));
      } on Object {
        // Invalid activities are ignored so legacy lessons remain usable.
      }
    }
    return activities;
  }

  static List<LessonQuizQuestionModel> _parseQuizQuestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => LessonQuizQuestionModel.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((question) => question.isValid)
        .toList();
  }

  static Map<String, dynamic> _activityToMap(LessonActivityModel activity) {
    return {
      'id': activity.id,
      'type': lessonActivityTypeToString(activity.type),
      'instruction': activity.instruction,
      'prompt': activity.prompt,
      'mediaUrl': activity.mediaUrl,
      'mediaType': activity.mediaType,
      'options': activity.options,
      'correctAnswer': activity.correctAnswer,
      'items': activity.items,
      'correctOrder': activity.correctOrder,
      'pairs': activity.pairs
          .map((pair) => {'left': pair.key, 'right': pair.value})
          .toList(),
      'activities': activity.activities.map(_activityToMap).toList(),
    };
  }
}
