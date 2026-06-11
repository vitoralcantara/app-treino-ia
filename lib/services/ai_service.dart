import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'document_service.dart';

class AiService {
  final String apiKey;
  GenerativeModel? _model;

  AiService({required this.apiKey});

  Future<void> _initModel() async {
    if (_model != null) return;

    String modelName = 'gemini-1.5-flash'; // Fallback

    try {
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List models = data['models'] ?? [];
        
        // Filtrar modelos flash que suportam geração de conteúdo
        final flashModels = models.where((m) {
          final name = (m['name'] as String).toLowerCase();
          final methods = (m['supportedGenerationMethods'] as List?) ?? [];
          return name.contains('flash') && methods.contains('generateContent');
        }).toList();

        if (flashModels.isNotEmpty) {
          // Ordenar para pegar a "maior" versão (simplificado por nome/versão)
          flashModels.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
          
          // O nome vem como "models/gemini-..."
          modelName = flashModels.first['name'].toString().replaceFirst('models/', '');
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar modelos dinamicamente, usando fallback: $e');
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
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
      await _initModel();
      
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

      final response = await _model!.generateContent([Content.multi(parts)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('A IA não retornou nenhuma resposta.');
      }
      
      return response.text!;
    } catch (e) {
      throw Exception('Falha ao comunicar com a IA: $e');
    }
  }
}
