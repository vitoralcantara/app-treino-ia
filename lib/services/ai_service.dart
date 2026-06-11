import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  final String apiKey;
  late final GenerativeModel _model;

  AiService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2, // Baixa temperatura para respostas mais determinísticas (JSON estruturado)
      ),
    );
  }

  Future<String> generateWorkout(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('A IA não retornou nenhuma resposta.');
      }
      
      return response.text!;
    } catch (e) {
      throw Exception('Falha ao comunicar com a IA: $e');
    }
  }
}
