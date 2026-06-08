class Exercise {
  final int? id;
  final String name;
  final String? category;
  final String? instructions;

  Exercise({
    this.id,
    required this.name,
    this.category,
    this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'instructions': instructions,
    };
  }
}
