import 'package:flutter_test/flutter_test.dart';
import 'package:power/models/exercise.dart';
import 'package:power/models/workout.dart';

void main() {
  group('Workout Model Tests', () {
    test('should convert to and from JSON', () {
      final exercises = [
        Exercise(id: 1, name: 'Supino', category: 'Peito'),
      ];
      final workout = Workout(id: 1, name: 'Treino A', exercises: exercises);

      final json = workout.toJson();
      expect(json['name'], 'Treino A');
      expect(json['exercises'][0]['name'], 'Supino');

      final fromJson = Workout.fromJson(json);
      expect(fromJson.name, 'Treino A');
      expect(fromJson.exercises.length, 1);
      expect(fromJson.exercises[0].name, 'Supino');
    });
  });
}
