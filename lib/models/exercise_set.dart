class ExerciseSet {
  final int? id;
  final int? exerciseId;
  final int? workoutSessionId;
  final int reps;
  final double weight;
  final DateTime? timestamp;

  ExerciseSet({
    this.id,
    this.exerciseId,
    this.workoutSessionId,
    required this.reps,
    required this.weight,
    this.timestamp,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      id: json['id'] as int?,
      exerciseId: (json['exerciseId'] ?? json['exercise_id']) as int?,
      workoutSessionId: (json['workoutSessionId'] ?? json['session_id']) as int?,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
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
    };
  }
}
