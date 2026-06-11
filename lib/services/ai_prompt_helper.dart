import 'dart:convert';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/user_profile.dart';

class AiPromptHelper {
  static String generateCreateWorkoutPrompt(String userRequest, UserProfile profile, List<Exercise> availableExercises) {
    String profileContext = '';
    
    if (profile.age.isNotEmpty || profile.weight.isNotEmpty || profile.goal.isNotEmpty) {
      String measurements = '';
      if (profile.arm.isNotEmpty || profile.chest.isNotEmpty || profile.thigh.isNotEmpty) {
        measurements = '''
- Medidas: Braço (${profile.arm}cm), Peito (${profile.chest}cm), Cintura (${profile.waist}cm), Quadril (${profile.hip}cm), Coxa (${profile.thigh}cm), Panturrilha (${profile.calf}cm).
''';
      }

      profileContext = '''
Meu perfil físico atual:
- Idade: ${profile.age}
- Peso: ${profile.weight} kg
- Altura: ${profile.height} cm
- Gênero: ${profile.gender}
- Experiência: ${profile.experienceLevel}
- Objetivo: ${profile.goal}
- Limitações: ${profile.limitations}
$measurements
''';
    }

    String exercisesContext = '';
    if (availableExercises.isNotEmpty) {
      final names = availableExercises.map((e) => '- ${e.name} (${e.category ?? "Geral"})').join('\n');
      exercisesContext = '''
Tenho preferência/disponibilidade para os seguintes exercícios:
$names

Tente utilizar preferencialmente estes exercícios na criação do treino. Se precisar de algo fora desta lista para completar a rotina, você pode sugerir, mas PRIORIZE os acima.
''';
    }

    return '''
Atue como um Personal Trainer. Com base no meu pedido abaixo e no meu perfil físico, crie uma rotina de treinos estruturada.
Se eu pedir uma rotina (como ABC), crie uma lista com todos os treinos.
Utilize técnicas avançadas se achar pertinente ou se eu pedir:
- **Bi-set/Tri-set/Super Série**: Agrupe exercícios usando o campo "group" com o mesmo ID (ex: "super1").
- **Drop set/Rest-pause**: Sugira a técnica no campo "technique" (valores: "drop_set", "rest_pause").

Responda EXCLUSIVAMENTE com o código JSON puro, sem textos antes ou depois, seguindo exatamente este formato:

[
  {
    "name": "Treino A - Peito e Tríceps",
    "exercises": [
      {
        "name": "Supino Reto",
        "category": "Peito",
        "suggested_sets": 4,
        "suggested_reps": 10,
        "notes": "Focar na cadência 3-1-1"
      },
      {
        "name": "Crucifixo Inclinado",
        "category": "Peito",
        "suggested_sets": 3,
        "suggested_reps": 12,
        "group": "super1"
      },
      {
        "name": "Flexão de Braços",
        "category": "Peito",
        "suggested_sets": 3,
        "suggested_reps": 15,
        "group": "super1",
        "notes": "Até a falha"
      },
      {
        "name": "Tríceps Corda",
        "category": "Tríceps",
        "suggested_sets": 3,
        "suggested_reps": 10,
        "technique": "drop_set"
      }
    ]
  }
]

$profileContext

$exercisesContext

Meu pedido: $userRequest
''';
  }

  static String generateRefinementPrompt(String userRequest, List<Map<String, dynamic>> history) {
    final historyJson = jsonEncode(history);
    return '''
Atue como um Personal Trainer. Analise meu histórico de treinos abaixo e responda ao meu pedido de ajuste ou dúvida.
Responda de forma técnica e concisa.

Histórico:
$historyJson

Meu pedido: $userRequest
''';
  }

  static String generateExportWorkoutPrompt(Workout workout) {
    final workoutJson = jsonEncode(workout.toJson());
    return '''
Analise meu treino atual abaixo e me dê sugestões de melhoria ou responda a dúvidas sobre ele.

Treino Atual (JSON):
$workoutJson
''';
  }

  static String generateExportHistoryPrompt(List<WorkoutSession> sessions) {
    final historyJson = jsonEncode(sessions.map((s) => s.toJson()).toList());
    return '''
Analise meu histórico de treinos e progresso de cargas abaixo. Me dê um feedback sobre minha evolução e sugira ajustes se necessário.

Histórico de Sessões (JSON):
$historyJson
''';
  }

  static List<Workout> parseAiResponse(String response) {
    try {
      // Extrai JSON se a IA tiver colocado em blocos de markdown
      final jsonMatch = RegExp(r'\[.*\]|\{.*\}', dotAll: true).firstMatch(response);
      final jsonString = jsonMatch?.group(0) ?? response;
      
      final dynamic decoded = jsonDecode(jsonString);
      
      if (decoded is List) {
        return decoded.map((data) => Workout.fromJson(data)).toList();
      } else if (decoded is Map<String, dynamic>) {
        return [Workout.fromJson(decoded)];
      }
      
      throw Exception('Formato JSON não reconhecido.');
    } catch (e) {
      throw Exception('Formato de resposta inválido. Certifique-se de copiar o JSON corretamente.');
    }
  }

  static List<Exercise> parseExerciseListAiResponse(String response) {
    try {
      final jsonMatch = RegExp(r'\[.*\]|\{.*\}', dotAll: true).firstMatch(response);
      final jsonString = jsonMatch?.group(0) ?? response;
      
      final dynamic decoded = jsonDecode(jsonString);
      
      if (decoded is List) {
        return decoded.map((data) => Exercise.fromJson(data as Map<String, dynamic>)).toList();
      } else if (decoded is Map<String, dynamic>) {
        return [Exercise.fromJson(decoded)];
      }
      
      throw Exception('Formato JSON não reconhecido.');
    } catch (e) {
      throw Exception('Formato de resposta inválido. Certifique-se de copiar o JSON corretamente.');
    }
  }
}
