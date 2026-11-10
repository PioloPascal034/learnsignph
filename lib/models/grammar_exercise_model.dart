import 'grammar_tile_model.dart';

/// Represents a document from the `grammarExercises` collection.
/// `lessonId` is nullable: populated when the exercise is in-lesson
/// practice, null when it's part of the standalone category-based
/// grammar test pool. See Firestore_Schema.docx section 2.
class GrammarExerciseModel {
  final String id;
  final String? lessonId;
  final String category;
  final String promptText;
  final String difficulty;
  final List<GrammarTileModel> tiles;
  final String explanation;
  final String contentValidationStatus;
  final List<String> sourceReferences;

  GrammarExerciseModel({
    required this.id,
    this.lessonId,
    required this.category,
    required this.promptText,
    required this.difficulty,
    required this.tiles,
    this.explanation = '',
    this.contentValidationStatus = '',
    this.sourceReferences = const [],
  });

  bool get hasValidSentenceOrder {
    if (promptText.trim().isEmpty || tiles.isEmpty) return false;

    final signIds = tiles.map((tile) => tile.signId).toSet();
    final positions = tiles.map((tile) => tile.correctPosition).toList()
      ..sort();
    return signIds.length == tiles.length &&
        positions
            .asMap()
            .entries
            .every((entry) => entry.value == entry.key + 1);
  }

  List<String> get correctSignOrder {
    final orderedTiles = [...tiles]
      ..sort((a, b) => a.correctPosition.compareTo(b.correctPosition));
    return orderedTiles.map((tile) => tile.signId).toList();
  }

  factory GrammarExerciseModel.fromMap(String id, Map<String, dynamic> map) {
    final rawTiles = (map['tiles'] as List<dynamic>? ?? []);
    return GrammarExerciseModel(
      id: id,
      lessonId: map['lessonId'] as String?,
      category: map['category'] ?? '',
      promptText: map['promptText'] ?? '',
      difficulty: map['difficulty'] ?? 'beginner',
      tiles: rawTiles
          .map((t) => GrammarTileModel.fromMap(Map<String, dynamic>.from(t)))
          .toList(),
      explanation: (map['explanation'] ?? '').toString(),
      contentValidationStatus: (map['contentValidationStatus'] ?? '').toString(),
      sourceReferences: (map['sourceReferences'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'category': category,
      'promptText': promptText,
      'difficulty': difficulty,
      'tiles': tiles.map((t) => t.toMap()).toList(),
      'explanation': explanation,
      'contentValidationStatus': contentValidationStatus,
      'sourceReferences': sourceReferences,
    };
  }
}
