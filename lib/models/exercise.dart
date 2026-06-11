class Exercise {
  final int? id;
  final String name;
  final String? category;
  final String? instructions;
  final String? imageUrl;
  final String? videoUrl;
  final bool isAvailable;
  final int? suggestedSets;
  final int? suggestedReps;
  final String? workoutSpecificNotes; // Novo: Observação específica para este exercício NESTE treino

  Exercise({
    this.id,
    required this.name,
    this.category,
    this.instructions,
    this.imageUrl,
    this.videoUrl,
    this.isAvailable = true,
    this.suggestedSets,
    this.suggestedReps,
    this.workoutSpecificNotes,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      videoUrl: (json['videoUrl'] ?? json['video_url']) as String?,
      isAvailable: (json['isAvailable'] ?? json['is_available'] ?? 1) == 1,
      suggestedSets: (json['suggestedSets'] ?? json['suggested_sets']) as int?,
      suggestedReps: (json['suggestedReps'] ?? json['suggested_reps']) as int?,
      workoutSpecificNotes: (json['workoutSpecificNotes'] ?? json['workout_specific_notes'] ?? json['notes']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (category != null) 'category': category,
      if (instructions != null) 'instructions': instructions,
      if (imageUrl != null) 'image_url': imageUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      'is_available': isAvailable ? 1 : 0,
      if (suggestedSets != null) 'suggested_sets': suggestedSets,
      if (suggestedReps != null) 'suggested_reps': suggestedReps,
      if (workoutSpecificNotes != null) 'workout_specific_notes': workoutSpecificNotes,
    };
  }
}
