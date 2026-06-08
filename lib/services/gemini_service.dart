import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/workout.dart';
import '../models/exercise.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService(this.apiKey) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<Workout> generateWorkout(String prompt, List<Exercise> availableExercises) async {
    final systemPrompt = '''
    Você é um personal trainer especialista em musculação.
    Crie um treino baseado no pedido do usuário.
    Responda EXCLUSIVAMENTE em formato JSON seguindo esta estrutura:
    {
      "name": "Nome do Treino",
      "exercises": [
        {
          "name": "Nome do Exercício",
          "category": "Grupo Muscular"
        }
      ]
    }
    Use apenas exercícios conhecidos.
    ''';

    final fullPrompt = '$systemPrompt\n\nPedido do usuário: $prompt';
    final content = [Content.text(fullPrompt)];
    final response = await _model.generateContent(content);
    
    final text = response.text;
    if (text == null) throw Exception('Resposta da IA vazia');

    // Extract JSON from response (sometimes IA adds markdown code blocks)
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    final jsonString = jsonMatch?.group(0) ?? text;

    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    // Map AI exercises to existing ones if possible, or create new ones
    return Workout.fromJson(data);
  }

  Future<String> refineWorkout(String userPrompt, List<Map<String, dynamic>> history) async {
    final historyJson = jsonEncode(history);
    final systemPrompt = '''
    Você é um personal trainer. Analise o histórico de treinos do usuário e responda ao pedido de refinamento.
    Histórico: $historyJson
    Seja conciso e técnico.
    ''';

    final content = [Content.text('$systemPrompt\n\nPedido: $userPrompt')];
    final response = await _model.generateContent(content);
    return response.text ?? 'Erro ao processar refinamento.';
  }
}
