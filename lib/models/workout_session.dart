import 'exercise_set.dart';

class WorkoutSession {
  final int? id;
  final int workoutId;
  final String workoutName;
  final DateTime date;
  final List<ExerciseSet> sets;

  WorkoutSession({
    this.id,
    required this.workoutId,
    required this.workoutName,
    required this.date,
    this.sets = const [],
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as int?,
      workoutId: json['workoutId'] as int,
      workoutName: json['workoutName'] as String,
      date: DateTime.parse(json['date'] as String),
      sets: (json['sets'] as List<dynamic>?)
              ?.map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'workoutId': workoutId,
      'workoutName': workoutName,
      'date': date.toIso8601String(),
      'sets': sets.map((e) => e.toJson()).toList(),
    };
  }
}
