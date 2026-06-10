import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../services/ai_prompt_helper.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseListAsync = ref.watch(exerciseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'Copiar Prompt para IA',
            onPressed: () => _copyAiPrompt(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Importar em Lote (JSON)',
            onPressed: () => _showBatchImportDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar Manual',
            onPressed: () => _showAddExerciseDialog(context, ref),
          ),
        ],
      ),
      body: exerciseListAsync.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Center(child: Text('Nenhum exercício cadastrado.'));
          }

          // Agrupar por categoria
          final Map<String, List<Exercise>> grouped = {};
          for (var ex in exercises) {
            final cat = ex.category ?? 'Geral';
            grouped.putIfAbsent(cat, () => []).add(ex);
          }

          final categories = grouped.keys.toList()..sort();

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final catExercises = grouped[cat]!;

              return ExpansionTile(
                title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                initiallyExpanded: true,
                children: catExercises.map((ex) => ListTile(
                  title: Text(ex.name),
                  subtitle: Text(ex.isAvailable ? 'Disponível para IA' : 'Indisponível'),
                  leading: Checkbox(
                    value: ex.isAvailable,
                    onChanged: (val) {
                      ref.read(exerciseListProvider.notifier).toggleExerciseAvailability(ex.id!, val ?? false);
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ex.videoUrl != null && ex.videoUrl!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, color: Colors.blue),
                          onPressed: () => _launchVideo(ex.videoUrl!),
                          tooltip: 'Ver vídeo',
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, ref, ex),
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Exercise ex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Exercício?'),
        content: Text('Isso removerá "${ex.name}" da sua biblioteca permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(exerciseListProvider.notifier).deleteExercise(ex.id!);
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final videoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Exercício'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Categoria (ex: Peito)')),
            TextField(
              controller: videoController, 
              decoration: const InputDecoration(
                labelText: 'URL do Vídeo (ex: YouTube)',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(exerciseListProvider.notifier).addExercise(
                  Exercise(
                    name: nameController.text,
                    category: categoryController.text,
                    videoUrl: videoController.text,
                    isAvailable: true,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _copyAiPrompt(BuildContext context) {
    const prompt = '''
Atue como um Personal Trainer. Sugira uma lista de exercícios de musculação.
Responda EXCLUSIVAMENTE com o código JSON puro, sem textos antes ou depois, seguindo exatamente este formato:

[
  {
    "name": "Nome do Exercício",
    "category": "Grupo Muscular",
    "video_url": "Link opcional do YouTube (se houver)",
    "instructions": "Breve instrução"
  }
]
''';
    Clipboard.setData(const ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt de sugestão copiado!')),
    );
  }

  void _showBatchImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar Exercícios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cole o JSON gerado pela IA abaixo para adicionar vários exercícios de uma vez.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Ex: [\\n  {"name": "...", "category": "..."}\\n]',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                try {
                  final exercises = AiPromptHelper.parseExerciseListAiResponse(controller.text);
                  for (var ex in exercises) {
                    ref.read(exerciseListProvider.notifier).addExercise(ex);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('\${exercises.length} exercícios importados!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao importar: \$e')),
                  );
                }
              }
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }
}
