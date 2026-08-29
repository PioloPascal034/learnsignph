/// Represents a document in users/{userId}/lessonProgress/{lessonId}.
/// One document per lesson the user has started or completed.
class LessonProgressModel {
  final String lessonId;
  final String status; // 'available' | 'inProgress' | 'completed'
  final double score;
  final DateTime? updatedAt;

  LessonProgressModel({
    required this.lessonId,
    required this.status,
    required this.score,
    this.updatedAt,
  });

  factory LessonProgressModel.fromMap(String lessonId, Map<String, dynamic> map) {
    return LessonProgressModel(
      lessonId: lessonId,
      status: map['status'] ?? 'available',
      score: (map['score'] ?? 0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'score': score,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
