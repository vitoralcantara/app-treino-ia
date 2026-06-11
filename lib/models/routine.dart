import 'workout.dart';

class Routine {
  final int? id;
  final String name;
  final DateTime createdAt;
  final bool isActive;
  final int? suggestedDurationWeeks;
  final String? frequencyType; // Novo: Tipo de frequência (daily, weekdays, weekly, etc)
  final String? frequencyValue; // Novo: Valor associado à frequência
  final List<Workout> workouts;

  Routine({
    this.id,
    required this.name,
    required this.createdAt,
    this.isActive = true,
    this.suggestedDurationWeeks,
    this.frequencyType,
    this.frequencyValue,
    this.workouts = const [],
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as int?,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: (json['is_active'] ?? 1) == 1,
      suggestedDurationWeeks: json['suggested_duration_weeks'] as int?,
      frequencyType: json['frequency_type'] as String?,
      frequencyValue: json['frequency_value'] as String?,
      workouts: [],
    );
  }

  Routine copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    bool? isActive,
    int? suggestedDurationWeeks,
    String? frequencyType,
    String? frequencyValue,
    List<Workout>? workouts,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      suggestedDurationWeeks: suggestedDurationWeeks ?? this.suggestedDurationWeeks,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyValue: frequencyValue ?? this.frequencyValue,
      workouts: workouts ?? this.workouts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      if (suggestedDurationWeeks != null) 'suggested_duration_weeks': suggestedDurationWeeks,
      if (frequencyType != null) 'frequency_type': frequencyType,
      if (frequencyValue != null) 'frequency_value': frequencyValue,
    };
  }
}
