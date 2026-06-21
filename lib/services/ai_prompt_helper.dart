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
Responda EXCLUSIVAMENTE com o código JSON puro seguindo este formato exato:

{
  "routine_name": "Nome",
  "suggested_duration_weeks": 4,
  "workouts": [
    {
      "name": "Treino A",
      "exercises": [
        {
          "name": "Exercício",
          "category": "Grupo Muscular",
          "suggested_sets": 3,
          "suggested_reps": 12,
          "suggested_reps_list": [12, 10, 8],
          "notes": "Observações/Instruções",
          "video_url": "link se houver",
          "group": "opcional_id",
          "technique": "opcional"
        }
      ]
    }
  ]
}

IMPORTANTE: Sempre inclua o campo "suggested_reps_list" com uma lista progressiva de repetições para cada série (ex: [12, 10, 8, 8]). Use padrões progressivos como [12, 10, 8] para drop-set ou [12, 10, 10] para pirâmide.

CORRESPONDÊNCIA DE EXERCÍCIOS: Quando sugerir exercícios, VERIFIQUE se já existe um exercício similar na lista de exercícios disponíveis acima. Se existir um exercício similar (ex: sugerir "triceps pulley" quando existe "triceps corda"), USE O NOME EXATO do exercício existente. Isso é crucial para garantir que o exercício seja reconhecido corretamente no aplicativo.

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

  static Map<String, dynamic> parseAiResponse(String response) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      final jsonString = jsonMatch?.group(0) ?? response;
      return jsonDecode(jsonString);
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
