import 'dart:convert';

class UserProfile {
  final String age;
  final String weight;
  final String height;
  final String gender;
  final String experienceLevel;
  final String goal;
  final String limitations;

  UserProfile({
    this.age = '',
    this.weight = '',
    this.height = '',
    this.gender = '',
    this.experienceLevel = '',
    this.goal = '',
    this.limitations = '',
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
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}
