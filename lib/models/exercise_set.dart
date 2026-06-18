class ExerciseSet {
  final int? id;
  final int? exerciseId;
  final int? workoutSessionId;
  final int reps;
  final String weight;
  final DateTime? timestamp;
  final String? technique; // Novo: Técnica aplicada (drop_set, rest_pause, etc)

  ExerciseSet({
    this.id,
    this.exerciseId,
    this.workoutSessionId,
    required this.reps,
    required this.weight,
    this.timestamp,
    this.technique,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      id: json['id'] as int?,
      exerciseId: (json['exerciseId'] ?? json['exercise_id']) as int?,
      workoutSessionId: (json['workoutSessionId'] ?? json['session_id']) as int?,
      reps: json['reps'] as int,
      weight: json['weight']?.toString() ?? '0',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      technique: json['technique'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (exerciseId != null) 'exerciseId': exerciseId,
      if (workoutSessionId != null) 'workoutSessionId': workoutSessionId,
      'reps': reps,
      'weight': weight,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (technique != null) 'technique': technique,
    };
  }
}
