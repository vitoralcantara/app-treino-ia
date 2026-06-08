import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';
import '../providers/workout_provider.dart';

class ApiKeyNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setKey(String key) => state = key;
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String>(ApiKeyNotifier.new);

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _promptController = TextEditingController();
  bool _isLoading = false;
  String _response = '';

  Future<void> _generateWorkout() async {
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira sua Gemini API Key')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final gemini = GeminiService(apiKey);
      final exercises = await ref.read(exerciseListProvider.future);
      final workout = await gemini.generateWorkout(_promptController.text, exercises);
      
      await ref.read(workoutListProvider.notifier).addWorkout(workout);
      
      setState(() {
        _response = 'Treino "${workout.name}" criado com sucesso!';
        _promptController.clear();
      });
    } catch (e) {
      setState(() => _response = 'Erro: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => ref.read(apiKeyProvider.notifier).setKey(val),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'O que você quer treinar hoje?',
                hintText: 'Ex: Treino de pernas focado em quadríceps',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateWorkout,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Gerar Treino com IA'),
            ),
            if (_response.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_response),
              ),
            ],
            const SizedBox(height: 30),
            const Divider(),
            const Text(
              'Dica: O Gemini analisará seu pedido e criará um treino estruturado que será adicionado automaticamente à sua lista.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
