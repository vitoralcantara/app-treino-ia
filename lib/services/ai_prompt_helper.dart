import 'dart:convert';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/user_profile.dart';

class AiPromptHelper {
  static String generateCreateWorkoutPrompt(String userRequest, UserProfile profile) {
    String profileContext = '';
    if (profile.age.isNotEmpty || profile.weight.isNotEmpty || profile.goal.isNotEmpty) {
      profileContext = '''
Meu perfil físico atual:
- Idade: ${profile.age}
- Peso: ${profile.weight} kg
- Altura: ${profile.height} cm
- Gênero: ${profile.gender}
- Experiência: ${profile.experienceLevel}
- Objetivo: ${profile.goal}
- Limitações: ${profile.limitations}
''';
    }

    return '''
Atue como um Personal Trainer. Com base no meu pedido abaixo e no meu perfil físico, crie um treino estruturado.
Responda EXCLUSIVAMENTE com o código JSON puro, sem textos antes ou depois, seguindo exatamente este formato:

{
  "name": "Nome do Treino",
  "exercises": [
    {
      "name": "Nome do Exercício",
      "category": "Grupo Muscular"
    }
  ]
}

$profileContext

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

  static Workout parseAiResponse(String response) {
    try {
      // Extrai JSON se a IA tiver colocado em blocos de markdown
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      final jsonString = jsonMatch?.group(0) ?? response;
      
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return Workout.fromJson(data);
    } catch (e) {
      throw Exception('Formato de resposta inválido. Certifique-se de copiar o JSON corretamente.');
    }
  }
}
