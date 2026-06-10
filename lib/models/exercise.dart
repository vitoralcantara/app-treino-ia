class Exercise {
  final int? id;
  final String name;
  final String? category;
  final String? instructions;
  final String? imageUrl;
  final bool isAvailable; // Nova propriedade para a biblioteca

  Exercise({
    this.id,
    required this.name,
    this.category,
    this.instructions,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      isAvailable: (json['isAvailable'] ?? json['is_available'] ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (category != null) 'category': category,
      if (instructions != null) 'instructions': instructions,
      if (imageUrl != null) 'image_url': imageUrl,
      'is_available': isAvailable ? 1 : 0,
    };
  }
}
