import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_prompt_helper.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _requestController = TextEditingController();
  final _responseController = TextEditingController();
  String _generatedPrompt = '';

  void _generatePrompt() {
    if (_requestController.text.isEmpty) return;
    
    final profile = ref.read(profileProvider);

    setState(() {
      _generatedPrompt = AiPromptHelper.generateCreateWorkoutPrompt(_requestController.text, profile);
    });

    Clipboard.setData(ClipboardData(text: _generatedPrompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copiado! Cole no chat do Gemini.')),
    );
  }

  void _importWorkout() {
    if (_responseController.text.isEmpty) return;

    try {
      final workouts = AiPromptHelper.parseAiResponse(_responseController.text);
      
      for (var workout in workouts) {
        ref.read(workoutListProvider.notifier).addWorkout(workout);
      }
      
      setState(() {
        _responseController.clear();
        _requestController.clear();
        _generatedPrompt = '';
      });

      final message = workouts.length > 1 
          ? '${workouts.length} treinos importados com sucesso!' 
          : 'Treino "${workouts[0].name}" importado com sucesso!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Gerar Prompt para IA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _requestController,
              decoration: const InputDecoration(
                labelText: 'O que você quer treinar?',
                hintText: 'Ex: Treino de hipertrofia ABC para 3 dias',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _generatePrompt,
              icon: const Icon(Icons.copy),
              label: const Text('Gerar e Copiar Prompt'),
            ),
            if (_generatedPrompt.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Text(
                  'Dica: Cole o prompt no Gemini (web/app), copie a resposta dele e cole abaixo.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              '2. Importar Resposta da IA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _responseController,
              decoration: const InputDecoration(
                labelText: 'Cole a resposta da IA aqui',
                hintText: 'Cole o JSON gerado pelo Gemini...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _importWorkout,
              icon: const Icon(Icons.download),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              label: const Text('Importar Treino'),
            ),
          ],
        ),
      ),
    );
  }
}
