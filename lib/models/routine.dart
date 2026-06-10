import 'workout.dart';

class Routine {
  final int? id;
  final String name;
  final DateTime createdAt;
  final bool isActive;
  final List<Workout> workouts;

  Routine({
    this.id,
    required this.name,
    required this.createdAt,
    this.isActive = true,
    this.workouts = const [],
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as int?,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: (json['is_active'] ?? 1) == 1,
      workouts: [], // Preenchido manualmente no database_helper
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }
}
