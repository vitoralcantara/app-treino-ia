import 'package:flutter_test/flutter_test.dart';
import 'package:app_treino_academia/models/workout.dart';
import 'package:app_treino_academia/models/exercise.dart';
import 'package:app_treino_academia/services/ai_prompt_helper.dart';

void main() {
  group('AiPromptHelper Tests', () {
    test('parseAiResponse should handle a single workout object', () {
      const jsonResponse = '''
      {
        "name": "Treino A",
        "exercises": [
          {"name": "Supino", "category": "Peito"}
        ]
      }
      ''';

      final workouts = AiPromptHelper.parseAiResponse(jsonResponse);
      
      expect(workouts.length, 1);
      expect(workouts[0].name, 'Treino A');
      expect(workouts[0].exercises.length, 1);
      expect(workouts[0].exercises[0].name, 'Supino');
    });

    test('parseAiResponse should handle a list of workout objects (ABC Routine)', () {
      const jsonResponse = '''
      [
        {
          "name": "Treino A",
          "exercises": [{"name": "Supino", "category": "Peito"}]
        },
        {
          "name": "Treino B",
          "exercises": [{"name": "Agachamento", "category": "Pernas"}]
        }
      ]
      ''';

      final workouts = AiPromptHelper.parseAiResponse(jsonResponse);
      
      expect(workouts.length, 2);
      expect(workouts[0].name, 'Treino A');
      expect(workouts[1].name, 'Treino B');
      expect(workouts[1].exercises[0].name, 'Agachamento');
    });

    test('parseAiResponse should handle markdown code blocks', () {
      const jsonResponse = '''
      Aqui está o seu treino:
      ```json
      [
        {
          "name": "Treino A",
          "exercises": [{"name": "Supino", "category": "Peito"}]
        }
      ]
      ```
      Espero que goste!
      ''';

      final workouts = AiPromptHelper.parseAiResponse(jsonResponse);
      
      expect(workouts.length, 1);
      expect(workouts[0].name, 'Treino A');
    });

    test('parseAiResponse should throw exception on invalid JSON', () {
      const invalidResponse = 'Isso não é um JSON';
      
      expect(() => AiPromptHelper.parseAiResponse(invalidResponse), throwsException);
    });
  });

  group('Model JSON Tests', () {
    test('Exercise.fromJson should handle image_url from snake_case', () {
      final json = {
        'id': 1,
        'name': 'Supino',
        'category': 'Peito',
        'image_url': 'https://example.com/image.png'
      };

      final exercise = Exercise.fromJson(json);
      
      expect(exercise.imageUrl, 'https://example.com/image.png');
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
