class LessonActivityProgressModel {
  final String activityId;
  final int attempts;
  final double bestScore;
  final String status;
  final DateTime? updatedAt;

  const LessonActivityProgressModel({
    required this.activityId,
    required this.attempts,
    required this.bestScore,
    required this.status,
    this.updatedAt,
  });

  factory LessonActivityProgressModel.fromMap(
      String activityId, Map<String, dynamic> map) {
    return LessonActivityProgressModel(
      activityId: activityId,
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      bestScore: (map['bestScore'] as num?)?.toDouble() ?? 0,
      status: (map['status'] ?? 'inProgress').toString(),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.tryParse(map['updatedAt'].toString()),
    );
  }

  Map<String, dynamic> toMap({DateTime? now}) {
    return {
      'attempts': attempts,
      'bestScore': bestScore,
      'status': status,
      'updatedAt': (now ?? DateTime.now()).toIso8601String(),
    };
  }
}
