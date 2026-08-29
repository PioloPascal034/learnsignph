/// Represents a single lesson document from the `lessons` collection.
/// `signIds` replaces the ERD's LessonSigns join table - Firestore has no
/// joins, so the related sign IDs are embedded directly as an array field.
/// See Firestore_Schema.docx section 2 for the rationale.
class LessonModel {
  final String id;
  final String title;
  final String category;
  final String videoUrl;
  final String description;
  final List<String> signIds;

  LessonModel({
    required this.id,
    required this.title,
    required this.category,
    required this.videoUrl,
    required this.description,
    required this.signIds,
  });

  factory LessonModel.fromMap(String id, Map<String, dynamic> map) {
    return LessonModel(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      description: map['description'] ?? '',
      signIds: List<String>.from(map['signIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'videoUrl': videoUrl,
      'description': description,
      'signIds': signIds,
    };
  }
}
