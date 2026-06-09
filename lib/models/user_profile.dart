import 'dart:convert';

class UserProfile {
  final String age;
  final String weight;
  final String height;
  final String gender;
  final String experienceLevel;
  final String goal;
  final String limitations;
  
  // Medidas corporais (opcionais)
  final String arm;
  final String chest;
  final String waist;
  final String hip;
  final String thigh;
  final String calf;

  UserProfile({
    this.age = '',
    this.weight = '',
    this.height = '',
    this.gender = '',
    this.experienceLevel = '',
    this.goal = '',
    this.limitations = '',
    this.arm = '',
    this.chest = '',
    this.waist = '',
    this.hip = '',
    this.thigh = '',
    this.calf = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'experienceLevel': experienceLevel,
      'goal': goal,
      'limitations': limitations,
      'arm': arm,
      'chest': chest,
      'waist': waist,
      'hip': hip,
      'thigh': thigh,
      'calf': calf,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      age: map['age'] ?? '',
      weight: map['weight'] ?? '',
      height: map['height'] ?? '',
      gender: map['gender'] ?? '',
      experienceLevel: map['experienceLevel'] ?? '',
      goal: map['goal'] ?? '',
      limitations: map['limitations'] ?? '',
      arm: map['arm'] ?? '',
      chest: map['chest'] ?? '',
      waist: map['waist'] ?? '',
      hip: map['hip'] ?? '',
      thigh: map['thigh'] ?? '',
      calf: map['calf'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}

