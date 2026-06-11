import 'workout.dart';

class Routine {
  final int? id;
  final String name;
  final DateTime createdAt;
  final bool isActive;
  final int? suggestedDurationWeeks; // Novo: Duração sugerida em semanas
  final List<Workout> workouts;

  Routine({
    this.id,
    required this.name,
    required this.createdAt,
    this.isActive = true,
    this.suggestedDurationWeeks,
    this.workouts = const [],
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as int?,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: (json['is_active'] ?? 1) == 1,
      suggestedDurationWeeks: json['suggested_duration_weeks'] as int?,
      workouts: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      if (suggestedDurationWeeks != null) 'suggested_duration_weeks': suggestedDurationWeeks,
    };
  }
}
