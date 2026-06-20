import 'package:flutter_test/flutter_test.dart';
import 'package:power/models/workout.dart';
import 'package:power/models/exercise.dart';
import 'package:power/services/ai_prompt_helper.dart';

void main() {
  group('AiPromptHelper Tests', () {
    test('parseAiResponse should handle a structured routine object', () {
      const jsonResponse = '''
      {
        "routine_name": "Fase 1",
        "suggested_duration_weeks": 4,
        "workouts": [
          {
            "name": "Treino A",
            "exercises": [
              {"name": "Supino", "category": "Peito"}
            ]
          }
        ]
      }
      ''';

      final data = AiPromptHelper.parseAiResponse(jsonResponse);
      
      expect(data['routine_name'], 'Fase 1');
      expect(data['suggested_duration_weeks'], 4);
      expect((data['workouts'] as List).length, 1);
      
      final workoutsJson = data['workouts'] as List;
      final workout = Workout.fromJson(workoutsJson[0] as Map<String, dynamic>);
      expect(workout.name, 'Treino A');
    });

    test('parseAiResponse should handle markdown code blocks', () {
      const jsonResponse = '''
      Aqui está o seu treino:
      ```json
      {
        "routine_name": "Fase 1",
        "workouts": []
      }
      ```
      Espero que goste!
      ''';

      final data = AiPromptHelper.parseAiResponse(jsonResponse);
      expect(data['routine_name'], 'Fase 1');
    });

    test('parseAiResponse should throw exception on invalid JSON', () {
      const invalidResponse = 'Isso não é um JSON';
      expect(() => AiPromptHelper.parseAiResponse(invalidResponse), throwsException);
    });
  });

  group('Model JSON Tests', () {
    test('Exercise.fromJson should handle all new fields', () {
      final json = {
        'id': 1,
        'name': 'Supino',
        'category': 'Peito',
        'image_url': 'https://example.com/image.png',
        'suggested_sets': 4,
        'suggested_reps': 10,
        'notes': 'Cadência lenta',
        'group_id': 'super1',
        'technique': 'drop_set'
      };

      final exercise = Exercise.fromJson(json);
      
      expect(exercise.imageUrl, 'https://example.com/image.png');
      expect(exercise.suggestedSets, 4);
      expect(exercise.suggestedReps, 10);
      expect(exercise.workoutSpecificNotes, 'Cadência lenta');
      expect(exercise.groupId, 'super1');
      expect(exercise.suggestedTechnique, 'drop_set');
    });

    test('Workout.toJson should include all exercises', () {
      final workout = Workout(
        name: 'Treino Teste',
        exercises: [
          Exercise(name: 'Ex 1', category: 'Cat 1'),
          Exercise(name: 'Ex 2', category: 'Cat 2'),
        ],
      );

      final json = workout.toJson();
      
      expect(json['name'], 'Treino Teste');
      expect((json['exercises'] as List).length, 2);
    });
  });
}
