import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_prompt_helper.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import 'exercise_library_screen.dart';

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return ShowCaseWidget(
      builder: (context) => const AiScreenContent(),
    );
  }
}

class AiScreenContent extends ConsumerStatefulWidget {
  const AiScreenContent({super.key});

  @override
  ConsumerState<AiScreenContent> createState() => _AiScreenContentState();
}

class _AiScreenContentState extends ConsumerState<AiScreenContent> {
  final _requestController = TextEditingController();
  final _responseController = TextEditingController();
  String _generatedPrompt = '';

  // Keys para o tutorial
  final GlobalKey _step1Key = GlobalKey();
  final GlobalKey _step2Key = GlobalKey();
  final GlobalKey _step3Key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('tutorial_ai_shown') ?? false;
    
    if (!shown && mounted) {
      // ignore: deprecated_member_use
      ShowCaseWidget.of(context).startShowCase([_step1Key, _step2Key, _step3Key]);
      await prefs.setBool('tutorial_ai_shown', true);
    }
  }

  static const String _jsonInstructionsText = '''
Atue como um especialista em musculação. Formate a rotina de treinos solicitada estritamente no formato JSON abaixo para que eu possa importar no meu aplicativo.

Regras de Formatação:
1. Responda EXCLUSIVAMENTE com o código JSON puro.
2. "routine_name": Nome do ciclo (ex: Hipertrofia Fase 1).
3. "suggested_duration_weeks": Quantas semanas o treino deve durar (ex: 4).
4. "workouts": Lista de treinos (ex: Treino A, B, C).
5. "suggested_sets" e "suggested_reps": Use APENAS números inteiros (ex: 12). NUNCA use texto como "12/10/8".
6. "group": (Opcional) Use o mesmo ID para exercícios em Bi-set/Super série.
7. "technique": (Opcional) Use "drop_set" ou "rest_pause".

Formato Exato:
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
          "notes": "Observações/Instruções",
          "video_url": "link se houver",
          "group": "opcional_id",
          "technique": "opcional"
        }
      ]
    }
  ]
}
''';

  void _generatePrompt() {
    if (_requestController.text.isEmpty) return;
    
    final profile = ref.read(profileProvider);
    final exercisesAsync = ref.read(exerciseListProvider);
    
    final List<Exercise> availableExercises = exercisesAsync.maybeWhen(
      data: (list) => list.where((e) => e.isAvailable).toList(),
      orElse: () => [],
    );

    setState(() {
      _generatedPrompt = AiPromptHelper.generateCreateWorkoutPrompt(_requestController.text, profile, availableExercises);
    });

    Clipboard.setData(ClipboardData(text: _generatedPrompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copiado! Cole no chat do Gemini.')),
    );
  }

  void _copyJsonInstructions() {
    Clipboard.setData(const ClipboardData(text: _jsonInstructionsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instruções JSON copiadas para o clipboard!')),
    );
  }

  Future<void> _downloadJsonInstructions() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/regras_formatacao_treino.txt');
      await file.writeAsString(_jsonInstructionsText);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Regras de Formatação para Treino IA',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar arquivo: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _importWorkout() async {
    await _processJsonImport(_responseController.text);
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      await _processJsonImport(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler arquivo: $e')),
        );
      }
    }
  }

  Future<void> _processJsonImport(String jsonText) async {
    if (jsonText.isEmpty) return;

    try {
      final Map<String, dynamic> data = AiPromptHelper.parseAiResponse(jsonText);
      
      final routineName = data['routine_name'] ?? 'Rotina IA - ${_formatDate(DateTime.now())}';
      final durationWeeks = data['suggested_duration_weeks'] as int?;
      final List<dynamic> workoutsJson = data['workouts'] ?? [];

      // 1. Arquivar a rotina atual
      await ref.read(workoutListProvider.notifier).archiveCurrentRoutine();
      
      // 2. Criar a nova rotina no banco
      final db = ref.read(databaseProvider);
      final newRoutineId = await db.createRoutine(routineName, durationWeeks: durationWeeks);
      
      // 3. Adicionar os treinos
      for (var workoutJson in workoutsJson) {
        final workout = Workout.fromJson(workoutJson);
        final workoutWithRoutine = Workout(
          name: workout.name,
          exercises: workout.exercises,
          routineId: newRoutineId,
          isActive: true,
        );
        await ref.read(workoutListProvider.notifier).addWorkout(workoutWithRoutine);
      }
      
      setState(() {
        _responseController.clear();
        _requestController.clear();
        _generatedPrompt = '';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rotina "$routineName" importada com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Atenção: A IA não substitui um instrutor. Execute com cuidado e respeite seus limites.',
                        style: TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.library_books, color: Colors.blue),
                  title: const Text('Minha Biblioteca de Exercícios'),
                  subtitle: const Text('Selecione o que você tem disponível'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
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
              Showcase(
                key: _step1Key,
                description: 'Passo 1: Gere um prompt otimizado com suas preferências para colar no Gemini ou ChatGPT.',
                child: ElevatedButton.icon(
                  onPressed: _generatePrompt,
                  icon: const Icon(Icons.copy),
                  label: const Text('Gerar e Copiar Prompt'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _copyJsonInstructions,
                icon: const Icon(Icons.code),
                label: const Text('Copiar Apenas Regras JSON'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _downloadJsonInstructions,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Baixar Regras em Arquivo'),
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
              Showcase(
                key: _step2Key,
                description: 'Passo 2: Após a IA responder, cole o código JSON completo exatamente aqui.',
                child: TextField(
                  controller: _responseController,
                  decoration: const InputDecoration(
                    labelText: 'Cole a resposta da IA aqui',
                    hintText: 'Cole o JSON gerado pelo Gemini...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ),
              const SizedBox(height: 10),
              Showcase(
                key: _step3Key,
                description: 'Passo 3: Por fim, clique em Importar Texto para transformar o JSON em um ciclo de treinos no seu app!',
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _importWorkout,
                        icon: const Icon(Icons.download),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        label: const Text('Importar Texto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _importFromFile,
                        icon: const Icon(Icons.upload_file),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        ),
                        label: const Text('Subir Arquivo'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
