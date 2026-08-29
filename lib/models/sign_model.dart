/// Represents a single FSL sign document from the `signs` collection.
///
/// `gifUrl` was added alongside the existing `videoUrl` specifically for
/// contexts where several signs are shown on screen at once (e.g. the
/// grammar drag-and-drop tiles) - looping GIFs are far smaller and cheaper
/// to display simultaneously than running multiple video players at once.
/// `videoUrl` (the full-quality clip) is still used for the lesson detail
/// screen, where only one sign plays at a time.
class SignModel {
  final String id;
  final String word;
  final String videoUrl;
  final String gifUrl;
  final String category;
  final String difficulty;

  SignModel({
    required this.id,
    required this.word,
    required this.videoUrl,
    required this.gifUrl,
    required this.category,
    required this.difficulty,
  });

  factory SignModel.fromMap(String id, Map<String, dynamic> map) {
    return SignModel(
      id: id,
      word: map['word'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      // Fall back to videoUrl if a gif hasn't been uploaded yet for this
      // sign, so older seeded signs don't break the UI while you backfill.
      gifUrl: map['gifUrl'] ?? map['videoUrl'] ?? '',
      category: map['category'] ?? '',
      difficulty: map['difficulty'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'videoUrl': videoUrl,
      'gifUrl': gifUrl,
      'category': category,
      'difficulty': difficulty,
    };
  }
}
