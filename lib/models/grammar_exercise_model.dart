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

  GrammarExerciseModel({
    required this.id,
    this.lessonId,
    required this.category,
    required this.promptText,
    required this.difficulty,
    required this.tiles,
  });

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'category': category,
      'promptText': promptText,
      'difficulty': difficulty,
      'tiles': tiles.map((t) => t.toMap()).toList(),
    };
  }
}
