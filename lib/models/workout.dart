import 'exercise.dart';

class Workout {
  final int? id;
  final String name;
  final List<Exercise> exercises;
  final bool isActive; // Novo: Controla se o treino faz parte da rotina atual

  Workout({
    this.id,
    required this.name,
    this.exercises = const [],
    this.isActive = true,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as int?,
      name: json['name'] as String,
      isActive: (json['isActive'] ?? json['is_active'] ?? 1) == 1,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}
