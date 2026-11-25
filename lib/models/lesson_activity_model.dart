enum LessonActivityType {
  identification,
  matching,
  ordering,
  conversation,
  mixed,
}

LessonActivityType? lessonActivityTypeFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'identification':
    case 'sign_identification':
    case 'video_identification':
      return LessonActivityType.identification;
    case 'matching':
    case 'image_matching':
      return LessonActivityType.matching;
    case 'ordering':
    case 'sign_ordering':
      return LessonActivityType.ordering;
    case 'conversation':
    case 'conversation_choice':
      return LessonActivityType.conversation;
    case 'mixed':
    case 'mixed_activity':
      return LessonActivityType.mixed;
    default:
      return null;
  }
}

String lessonActivityTypeToString(LessonActivityType type) {
  switch (type) {
    case LessonActivityType.identification:
      return 'identification';
    case LessonActivityType.matching:
      return 'matching';
    case LessonActivityType.ordering:
      return 'ordering';
    case LessonActivityType.conversation:
      return 'conversation';
    case LessonActivityType.mixed:
      return 'mixed';
  }
}

/// A backward-compatible activity document embedded in lessons/{lessonId}.
///
/// Proposed Firestore shape:
/// {
///   id, type, instruction, prompt, mediaUrl, mediaType,
///   options, correctAnswer, items, correctOrder,
///   pairs: [{left, right}], activities: [...]
/// }
class LessonActivityModel {
  final String id;
  final LessonActivityType type;
  final String instruction;
  final String prompt;
  final String mediaUrl;
  final String mediaType;
  final List<String> options;
  final String correctAnswer;
  final List<String> items;
  final List<String> correctOrder;
  final List<MapEntry<String, String>> pairs;
  final List<LessonActivityModel> activities;

  const LessonActivityModel({
    required this.id,
    required this.type,
    this.instruction = '',
    this.prompt = '',
    this.mediaUrl = '',
    this.mediaType = '',
    this.options = const [],
    this.correctAnswer = '',
    this.items = const [],
    this.correctOrder = const [],
    this.pairs = const [],
    this.activities = const [],
  });

  factory LessonActivityModel.fromMap(
      String fallbackId, Map<String, dynamic> map) {
    final type = lessonActivityTypeFromString(
      (map['type'] ?? map['questionType']) as String?,
    );
    if (type == null) {
      throw const FormatException('Activity type is missing or unsupported.');
    }

    final rawPairs = map['pairs'] as List<dynamic>? ?? const [];
    final pairs = rawPairs.map((raw) {
      final pair = Map<String, dynamic>.from(raw as Map);
      return MapEntry(
        (pair['left'] ?? '').toString(),
        (pair['right'] ?? '').toString(),
      );
    }).toList();

    final rawActivities = map['activities'] as List<dynamic>? ?? const [];
    final activities = rawActivities.asMap().entries.map((entry) {
      return LessonActivityModel.fromMap(
        '${map['id'] ?? fallbackId}_${entry.key}',
        Map<String, dynamic>.from(entry.value as Map),
      );
    }).toList();

    return LessonActivityModel(
      id: (map['id'] ?? fallbackId).toString(),
      type: type,
      instruction: (map['instruction'] ?? '').toString(),
      prompt: (map['prompt'] ?? map['promptText'] ?? '').toString(),
      mediaUrl: (map['mediaUrl'] ?? '').toString(),
      mediaType: (map['mediaType'] ?? '').toString().toLowerCase(),
      options: _stringList(map['options']),
      correctAnswer: (map['correctAnswer'] ?? map['answer'] ?? '').toString(),
      items: _stringList(map['items']),
      correctOrder: _stringList(map['correctOrder']),
      pairs: pairs,
      activities: activities,
    );
  }

  bool get isValid {
    switch (type) {
      case LessonActivityType.identification:
      case LessonActivityType.conversation:
        return prompt.trim().isNotEmpty &&
            options.length >= 2 &&
            correctAnswer.trim().isNotEmpty &&
            options.contains(correctAnswer);
      case LessonActivityType.matching:
        return pairs.isNotEmpty &&
            pairs.every((pair) =>
                pair.key.trim().isNotEmpty && pair.value.trim().isNotEmpty);
      case LessonActivityType.ordering:
        return items.length >= 2 &&
            correctOrder.length == items.length &&
            _sameValues(items, correctOrder);
      case LessonActivityType.mixed:
        return activities.isNotEmpty &&
            activities.every((activity) => activity.isValid);
    }
  }

  List<LessonActivityModel> flatten() {
    if (type != LessonActivityType.mixed) return [this];
    return activities.expand((activity) => activity.flatten()).toList();
  }

  static LessonActivityModel fromSign({
    required String id,
    required String word,
    required String mediaUrl,
    required String mediaType,
    required List<String> distractors,
  }) {
    final options = <String>{word, ...distractors}
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return LessonActivityModel(
      id: id,
      type: LessonActivityType.identification,
      instruction: 'Watch the reference and identify the sign.',
      prompt: 'What does this sign mean?',
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      options: options,
      correctAnswer: word,
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static bool _sameValues(List<String> first, List<String> second) {
    final left = [...first]..sort();
    final right = [...second]..sort();
    return left.length == right.length &&
        List.generate(left.length, (index) => left[index] == right[index])
            .every((same) => same);
  }
}
