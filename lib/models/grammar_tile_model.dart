/// Represents one draggable tile within a GrammarExercise, embedded as
/// part of grammarExercises/{exerciseId}.tiles[] in Firestore (see
/// Firestore_Schema.docx section 4.3 - tiles are always fetched together
/// with their parent exercise, so they're embedded rather than a separate
/// collection).
class GrammarTileModel {
  final String signId;
  final int correctPosition;

  GrammarTileModel({
    required this.signId,
    required this.correctPosition,
  });

  factory GrammarTileModel.fromMap(Map<String, dynamic> map) {
    return GrammarTileModel(
      signId: map['signId'] ?? '',
      correctPosition: (map['correctPosition'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'signId': signId,
      'correctPosition': correctPosition,
    };
  }
}
