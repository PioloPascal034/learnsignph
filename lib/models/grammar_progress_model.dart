/// Represents a document in users/{userId}/grammarProgress/{exerciseId}.
class GrammarProgressModel {
  final String exerciseId;
  final String mode; // 'lesson' | 'test'
  final String status; // 'inProgress' | 'completed'
  final double score;
  final int attempts;

  GrammarProgressModel({
    required this.exerciseId,
    required this.mode,
    required this.status,
    required this.score,
    required this.attempts,
  });

  factory GrammarProgressModel.fromMap(String exerciseId, Map<String, dynamic> map) {
    return GrammarProgressModel(
      exerciseId: exerciseId,
      mode: map['mode'] ?? 'lesson',
      status: map['status'] ?? 'inProgress',
      score: (map['score'] ?? 0).toDouble(),
      attempts: (map['attempts'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'status': status,
      'score': score,
      'attempts': attempts,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
