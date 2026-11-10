import '../models/lesson_activity_model.dart';

class LessonActivityEngine {
  static List<LessonActivityModel> validActivities(
      Iterable<LessonActivityModel> activities) {
    return activities
        .expand((activity) => activity.flatten())
        .where((activity) => activity.isValid)
        .toList();
  }

  static bool isCorrect(
    LessonActivityModel activity, {
    String? answer,
    List<String>? orderedItems,
    Map<String, String>? matching,
  }) {
    switch (activity.type) {
      case LessonActivityType.identification:
      case LessonActivityType.conversation:
        return answer == activity.correctAnswer;
      case LessonActivityType.ordering:
        return _sameList(orderedItems ?? const [], activity.correctOrder);
      case LessonActivityType.matching:
        if (matching == null || matching.length != activity.pairs.length) {
          return false;
        }
        return activity.pairs.every((pair) => matching[pair.key] == pair.value);
      case LessonActivityType.mixed:
        return false;
    }
  }

  static double score({required int correct, required int total}) {
    if (total <= 0) return 0;
    return (correct.clamp(0, total) / total) * 100;
  }

  static bool _sameList(List<String> first, List<String> second) {
    return first.length == second.length &&
        List.generate(first.length, (index) => first[index] == second[index])
            .every((same) => same);
  }
}
