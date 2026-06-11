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
  final List<int>? suggestedRepsList; // Novo: Lista de reps por série (ex: [12, 10, 10, 8])
  final String? workoutSpecificNotes;
  final String? groupId;
  final String? suggestedTechnique;

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
    this.suggestedRepsList,
    this.workoutSpecificNotes,
    this.groupId,
    this.suggestedTechnique,
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
      suggestedSets: _parseSafeInt(json['suggestedSets'] ?? json['suggested_sets']),
      suggestedReps: _parseSafeInt(json['suggestedReps'] ?? json['suggested_reps']),
      suggestedRepsList: _parseSafeIntList(json['suggested_reps_list'] ?? json['suggestedRepsList'] ?? json['suggested_reps']),
      workoutSpecificNotes: (json['workoutSpecificNotes'] ?? json['workout_specific_notes'] ?? json['notes']) as String?,
      groupId: (json['groupId'] ?? json['group'] ?? json['group_id']) as String?,
      suggestedTechnique: (json['suggestedTechnique'] ?? json['technique'] ?? json['suggested_technique']) as String?,
    );
  }

  static int? _parseSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final match = RegExp(r'\d+').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
    }
    return null;
  }

  static List<int>? _parseSafeIntList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }
    if (value is String) {
      // Trata formatos como "12/10/8" ou "12, 10, 8" ou "12-10-8"
      final matches = RegExp(r'\d+').allMatches(value);
      if (matches.isNotEmpty) {
        return matches.map((m) => int.parse(m.group(0)!)).toList();
      }
    }
    return null;
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
      if (suggestedRepsList != null) 'suggested_reps_list': suggestedRepsList,
      if (workoutSpecificNotes != null) 'workout_specific_notes': workoutSpecificNotes,
      if (groupId != null) 'group_id': groupId,
      if (suggestedTechnique != null) 'technique': suggestedTechnique,
    };
  }
}
