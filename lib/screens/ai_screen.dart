import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_prompt_helper.dart';
import '../services/document_service.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/backup_provider.dart';
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
  bool _isLoading = false;
  // No web, guardamos bytes + nome. No mobile, File.
  final List<dynamic> _selectedFiles = [];

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

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'xls', 'txt'],
        withData: kIsWeb, // Necessário no Web para obter os bytes
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedFiles.addAll(result.files.map((f) => {
              'name': f.name,
              'bytes': f.bytes,
            }));
          } else {
            _selectedFiles.addAll(result.files.where((file) => file.path != null).map((file) => File(file.path!)));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivos: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  static const String _jsonInstructionsText = '''
Atue como um especialista em musculação. Formate a rotina de treinos solicitada estritamente no formato JSON abaixo para que eu possa importar no meu aplicativo.

Regras de Formatação:
1. Responda EXCLUSIVAMENTE com o código JSON puro.
2. "routine_name": Nome do ciclo (ex: Hipertrofia Fase 1).
3. "suggested_duration_weeks": Quantas semanas o treino deve durar (ex: 4).
4. "workouts": Lista de treinos (ex: Treino A, B, C).
5. "suggested_sets": Número de séries para o exercício (ex: 3).
6. "suggested_reps": Repetições para a primeira série (ex: 12).
7. "suggested_reps_list": (OBRIGATÓRIO) Lista de reps para cada série em formato progressivo (ex: [12, 10, 8] para drop-set ou [12, 10, 10] para pirâmide). Use padrão [12, 10, 8] para hipertrofia.
8. "group": (Opcional) Use o mesmo ID para exercícios em Bi-set/Super série.
9. "technique": (Opcional) Use "drop_set", "rest_pause", ou null.

IMPORTANTE - Correspondência de Exercícios:
10. Quando sugerir um exercício, VERIFIQUE se já existe um exercício similar na lista de exercícios disponíveis do aplicativo.
11. Se existir um exercício similar (ex: sugerir "triceps pulley" quando existe "triceps corda"), USE O NOME EXATO do exercício existente.
12. Exemplos de correspondências comuns:
    - "triceps pulley" → "triceps corda"
    - "leg press 45" → "leg press"
    - "remada curvada" → "remada"
    - "supino reto" → "supino"
    - "agachamento livre" → "agachamento"
13. Isso é crucial para garantir que o exercício seja reconhecido corretamente no aplicativo.

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

  Future<void> _generateWithAi() async {
    if (_requestController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, descreva o treino que deseja gerar.')),
      );
      return;
    }

    final aiService = ref.read(aiServiceProvider);
    if (aiService == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Necessária'),
          content: const Text('Para usar a geração automática, você precisa configurar sua Google Gemini API Key na tela de Perfil.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // A navegação para o perfil depende de como o HomeScreen gerencia as abas,
                // mas geralmente avisar o usuário é o primeiro passo.
              },
              child: const Text('Ir para Perfil'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<ProcessedDocument> processedDocs = [];
      final docService = DocumentService();
      
      for (var file in _selectedFiles) {
        final doc = await docService.processFile(file);
        processedDocs.add(doc);
      }

      final profile = ref.read(profileProvider);
      final exercisesAsync = ref.read(exerciseListProvider);
      final List<Exercise> availableExercises = exercisesAsync.maybeWhen(
        data: (list) => list.where((e) => e.isAvailable).toList(),
        orElse: () => [],
      );

      final prompt = AiPromptHelper.generateCreateWorkoutPrompt(
        _requestController.text,
        profile,
        availableExercises,
      );

      final response = await aiService.generateWorkout(prompt, documents: processedDocs);
      
      setState(() {
        _responseController.text = response;
        _isLoading = false;
        _selectedFiles.clear(); // Limpar arquivos após sucesso
      });

      // Se a resposta parece ser um JSON válido, já podemos processar ou pelo menos avisar
      if (mounted && response.contains('{')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treino gerado! Clique em "Importar Texto" para finalizar.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na geração: $e')),
        );
      }
    }
  }

  Future<void> _copyJsonInstructions() async {
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            text: _jsonInstructionsText,
            subject: 'Regras de Formatação JSON para Treino IA',
          ),
        );
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/regras_formatacao_treino_ia.json');
        await file.writeAsString(_jsonInstructionsText);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Regras de Formatação JSON para Treino IA',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar arquivo JSON: $e')),
        );
      }
    }
  }

  Future<void> _downloadJsonInstructions() async {
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            text: _jsonInstructionsText,
            subject: 'Regras de Formatação para Treino IA',
          ),
        );
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/regras_formatacao_treino.txt');
        await file.writeAsString(_jsonInstructionsText);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Regras de Formatação para Treino IA',
          ),
        );
      }
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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        withData: kIsWeb,
      );

      if (result == null || result.files.single.path == null && result.files.single.bytes == null) return;

      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        final pickedFile = File(result.files.single.path!);
        content = await pickedFile.readAsString();
      }
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

      if (!mounted) return;

      // Mostrar diálogo de escolha
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nova Rotina Gerada'),
          content: Text('Deseja substituir sua rotina atual pela "$routineName" ou apenas adicioná-la à sua lista?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'add'),
              child: const Text('Apenas Adicionar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('Substituir Atual'),
            ),
          ],
        ),
      );

      if (choice == null) return;

      final bool shouldReplace = choice == 'replace';

      // 1. Se for substituir, arquivar a rotina atual
      if (shouldReplace) {
        await ref.read(workoutListProvider.notifier).archiveCurrentRoutine();
      }
      
      // 2. Criar a nova rotina no banco
      final db = ref.read(databaseProvider);
      final newRoutineId = await db.createRoutine(
        routineName, 
        durationWeeks: durationWeeks,
        // Se não for substituir, a nova rotina entra como inativa (0)
        isActive: shouldReplace ? 1 : 0, 
      );
      
      // Disparar sincronização automática para salvar a nova rotina
      ref.read(backupProvider.notifier).triggerAutoSync();
      
      // 3. Adicionar os treinos
      for (var workoutJson in workoutsJson) {
        final workout = Workout.fromJson(workoutJson);
        final workoutWithRoutine = Workout(
          name: workout.name,
          exercises: workout.exercises,
          routineId: newRoutineId,
          isActive: shouldReplace, // Segue o estado da rotina
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
        SnackBar(
          content: Text(shouldReplace 
            ? 'Rotina "$routineName" ativada com sucesso!' 
            : 'Rotina "$routineName" adicionada à sua lista!'),
        ),
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  title: const Text(
                    'Minha Biblioteca de Exercícios',
                    maxLines: null,
                    softWrap: true,
                  ),
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
              
              // Seção de Arquivos
              if (_selectedFiles.isNotEmpty) ...[
                const Text('Arquivos Anexados:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      String fileName = '';
                      if (kIsWeb) {
                        fileName = file['name'];
                      } else {
                        fileName = (file as File).path.split('/').last;
                      }
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.insert_drive_file, size: 20),
                        title: Text(
                          fileName,
                          style: const TextStyle(fontSize: 12),
                          maxLines: null,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _removeFile(index),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickDocuments,
                icon: const Icon(Icons.attach_file),
                label: const Text('Anexar PDF, Word, Excel ou Texto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 10),
              if (ref.watch(aiServiceProvider) != null) ...[
                Showcase(
                  key: _step1Key,
                  description: 'Passo 1: Gere seu treino automaticamente usando o Google Gemini.',
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateWithAi,
                    icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                    label: Text(_isLoading ? 'Gerando...' : 'Gerar com Gemini (Auto)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade100,
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(child: Text('OU', style: TextStyle(fontSize: 10, color: Colors.grey))),
                const SizedBox(height: 10),
              ],
              if (ref.watch(aiServiceProvider) == null) 
                Showcase(
                  key: _step1Key,
                  description: 'Passo 1: Gere um prompt otimizado com suas preferências para colar no Gemini ou ChatGPT.',
                  child: ElevatedButton.icon(
                    onPressed: _generatePrompt,
                    icon: const Icon(Icons.copy),
                    label: const Text('Gerar e Copiar Prompt'),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _generatePrompt,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar Prompt Manual'),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _copyJsonInstructions,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Baixar Regras JSON'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _downloadJsonInstructions,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Baixar Regras em TXT'),
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
                  decoration: InputDecoration(
                    labelText: 'Cole a resposta da IA aqui',
                    hintText: 'Cole o JSON gerado pelo Gemini...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _responseController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _responseController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    setState(() {}); // Para atualizar o ícone de limpar
                  },
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
