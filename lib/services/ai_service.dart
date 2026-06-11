import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_service.dart';

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
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  Future<String> generateWorkout(String prompt, {List<ProcessedDocument>? documents}) async {
    try {
      final List<Part> parts = [TextPart(prompt)];

      if (documents != null && documents.isNotEmpty) {
        for (var doc in documents) {
          if (doc.type == DocumentType.pdf && doc.bytes != null) {
            parts.add(DataPart('application/pdf', doc.bytes!));
          } else if (doc.textContent != null) {
            parts.add(TextPart('\n--- CONTEÚDO DO ARQUIVO: ${doc.fileName} ---\n${doc.textContent}\n--- FIM DO ARQUIVO ---'));
          }
        }
      }

      final response = await _model.generateContent([Content.multi(parts)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('A IA não retornou nenhuma resposta.');
      }
      
      return response.text!;
    } catch (e) {
      throw Exception('Falha ao comunicar com a IA: $e');
    }
  }
}
