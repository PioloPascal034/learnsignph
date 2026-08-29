/// Represents a single FSL sign document from the `signs` collection.
/// See Firestore_Schema.docx section 2 for the collection mapping.
class SignModel {
  final String id;
  final String word;
  final String videoUrl;
  final String category;
  final String difficulty;

  SignModel({
    required this.id,
    required this.word,
    required this.videoUrl,
    required this.category,
    required this.difficulty,
  });

  factory SignModel.fromMap(String id, Map<String, dynamic> map) {
    return SignModel(
      id: id,
      word: map['word'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      category: map['category'] ?? '',
      difficulty: map['difficulty'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'videoUrl': videoUrl,
      'category': category,
      'difficulty': difficulty,
    };
  }
}
