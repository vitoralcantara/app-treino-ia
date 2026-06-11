import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../services/notification_service.dart';

class WorkoutExecutionScreen extends ConsumerStatefulWidget {
  final Workout workout;

  const WorkoutExecutionScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends ConsumerState<WorkoutExecutionScreen> {
  final Map<int, List<ExerciseSet>> _setsByExercise = {};
  final Map<int, List<bool>> _completedSets = {}; // Controla quais séries foram concluídas
  final List<Exercise> _dynamicExercises = []; // Exercícios adicionados na hora
  bool _initialized = false;

  // Variáveis do Temporizador de Descanso
  Timer? _timer;
  int _seconds = 0;
  bool _isTimerRunning = false;
  int _selectedRestTime = 60; // Tempo de descanso padrão: 60s

  @override
  void dispose() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    super.dispose();
  }

  void _startTimer() {
    if (_isTimerRunning) return;
    setState(() {
      _isTimerRunning = true;
    });
    
    // Agendar notificação para o fim do tempo selecionado
    NotificationService().scheduleRestNotification(_selectedRestTime - _seconds > 0 ? _selectedRestTime - _seconds : _selectedRestTime);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        if (_seconds >= _selectedRestTime) {
          _pauseTimer();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    setState(() {
      _seconds = 0;
      _isTimerRunning = false;
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o vídeo: $url')),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _loadLastSessionData();
      _initialized = true;
    }
  }

  void _loadLastSessionData() {
    final sessions = ref.read(sessionListProvider);
    _dynamicExercises.clear();
    _dynamicExercises.addAll(widget.workout.exercises);

    // Encontrar a última sessão deste treino específico
    final lastSession = sessions.firstWhere(
      (s) => s.workoutId == widget.workout.id,
      orElse: () => WorkoutSession(
        workoutId: widget.workout.id!,
        workoutName: widget.workout.name,
        date: DateTime.now(),
      ),
    );

    setState(() {
      for (var exercise in _dynamicExercises) {
        // Buscar séries desta última sessão para este exercício
        final previousSets = lastSession.sets.where((s) => s.exerciseId == exercise.id).toList();
        
        if (previousSets.isNotEmpty) {
          _setsByExercise[exercise.id!] = previousSets.map((s) => ExerciseSet(
            reps: s.reps,
            weight: s.weight,
            exerciseId: exercise.id,
          )).toList();
          _completedSets[exercise.id!] = List.generate(previousSets.length, (_) => false);
        } else {
          // Usar sugestão da IA se disponível, senão padrão
          final suggestedSets = exercise.suggestedSets ?? 3;
          final suggestedReps = exercise.suggestedReps ?? 10;
          
          _setsByExercise[exercise.id!] = List.generate(
            suggestedSets, 
            (_) => ExerciseSet(reps: suggestedReps, weight: 0, exerciseId: exercise.id),
          );
          _completedSets[exercise.id!] = List.generate(suggestedSets, (_) => false);
        }
      }
    });
  }

  void _addNewExercise(Exercise exercise) {
    if (_setsByExercise.containsKey(exercise.id)) return;

    setState(() {
      _dynamicExercises.add(exercise);
      _setsByExercise[exercise.id!] = [
        ExerciseSet(reps: 10, weight: 0, exerciseId: exercise.id),
      ];
      _completedSets[exercise.id!] = [false];
    });

    // Opcional: Salvar no treino original para sempre
    _confirmSaveToWorkout(exercise);
  }

  void _confirmSaveToWorkout(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar na Rotina?'),
        content: Text('Deseja adicionar "${exercise.name}" permanentemente a este treino para as próximas vezes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Apenas Hoje')),
          ElevatedButton(
            onPressed: () {
              ref.read(workoutListProvider.notifier).addExerciseToWorkout(widget.workout.id!, exercise.id!);
              Navigator.pop(context);
            },
            child: const Text('Salvar Sempre'),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Adicionar Exercício', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final exerciseListAsync = ref.watch(exerciseListProvider);
                  return exerciseListAsync.when(
                    data: (exercises) => ListView.builder(
                      controller: scrollController,
                      itemCount: exercises.length + 1,
                      itemBuilder: (context, index) {
                        if (index == exercises.length) {
                          return ListTile(
                            leading: const Icon(Icons.add_circle, color: Colors.green),
                            title: const Text('Criar Novo Exercício'),
                            onTap: () {
                              Navigator.pop(context);
                              _showCreateCustomExerciseDialog();
                            },
                          );
                        }
                        final ex = exercises[index];
                        return ListTile(
                          title: Text(ex.name),
                          subtitle: Text(ex.category ?? ''),
                          onTap: () {
                            _addNewExercise(ex);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erro: $e')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCustomExerciseDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    String? pickedImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Novo Exercício'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Categoria (Peito, Pernas...)')),
              const SizedBox(height: 16),
              if (pickedImagePath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(
                      File(pickedImagePath!),
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setStateDialog(() {
                      pickedImagePath = image.path;
                    });
                  }
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Selecionar Imagem da Galeria'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final exercise = Exercise(
                    name: nameController.text, 
                    category: categoryController.text,
                    imageUrl: pickedImagePath, // Usa o caminho local
                  );
                  await ref.read(exerciseListProvider.notifier).addExercise(exercise);
                  
                  // Buscar o exercício recém criado no banco via provider
                  final db = ref.read(databaseProvider);
                  final updatedList = await db.getAllExercises();
                  final newEx = updatedList.firstWhere((e) => e.name == exercise.name);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _addNewExercise(newEx);
                  }
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSet(int exerciseId) {
    setState(() {
      final lastSet = _setsByExercise[exerciseId]!.last;
      _setsByExercise[exerciseId]!.add(
        ExerciseSet(
          reps: lastSet.reps,
          weight: lastSet.weight,
          exerciseId: exerciseId,
        ),
      );
      _completedSets[exerciseId]!.add(false);
    });
  }

  void _finishWorkout() async {
    final List<ExerciseSet> completedSetsList = [];
    
    // Salvar APENAS as séries que foram marcadas como concluídas
    _setsByExercise.forEach((exerciseId, sets) {
      final completedStatus = _completedSets[exerciseId]!;
      for (int i = 0; i < sets.length; i++) {
        if (completedStatus[i]) {
          completedSetsList.add(sets[i]);
        }
      }
    });

    if (completedSetsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marque pelo menos uma série como concluída!')),
      );
      return;
    }

    final session = WorkoutSession(
      workoutId: widget.workout.id!,
      workoutName: widget.workout.name,
      date: DateTime.now(),
      sets: completedSetsList,
    );

    await ref.read(sessionListProvider.notifier).addSession(session);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino concluído e salvo no histórico!')),
      );
      Navigator.pop(context);
    }
  }

  void _showExerciseHistory(Exercise exercise) async {
    final db = ref.read(databaseProvider);
    final history = await db.getExerciseHistory(exercise.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Histórico: ${exercise.name}', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('Nenhum histórico encontrado para este exercício.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final record = history[index];
                        final dateStr = record['date'] as String;
                        final date = DateTime.parse(dateStr);
                        final reps = record['reps'];
                        final weight = record['weight'];

                        return ListTile(
                          leading: const Icon(Icons.fitness_center),
                          title: Text('$weight kg x $reps reps'),
                          subtitle: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseNotesDialog(Exercise exercise) {
    final controller = TextEditingController(text: exercise.workoutSpecificNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Observações: ${exercise.name}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Cadência lenta, focar na contração...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(workoutListProvider.notifier).updateExerciseNotesInWorkout(
                widget.workout.id!, 
                exercise.id!, 
                controller.text,
              );
              if (mounted) {
                // Atualizar o objeto local para refletir na UI sem precisar recarregar tudo
                setState(() {
                  final index = _dynamicExercises.indexOf(exercise);
                  if (index != -1) {
                    _dynamicExercises[index] = Exercise(
                      id: exercise.id,
                      name: exercise.name,
                      category: exercise.category,
                      instructions: exercise.instructions,
                      imageUrl: exercise.imageUrl,
                      videoUrl: exercise.videoUrl,
                      isAvailable: exercise.isAvailable,
                      suggestedSets: exercise.suggestedSets,
                      suggestedReps: exercise.suggestedReps,
                      workoutSpecificNotes: controller.text,
                    );
                  }
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Executando: ${widget.workout.name}'),
      ),
      body: Column(
        children: [
          // Widget do Temporizador de Descanso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRestTime,
                            isDense: true,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            items: [30, 45, 60, 90, 120].map((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text('${value}s DESCANSO'),
                              );
                            }).toList(),
                            onChanged: _isTimerRunning ? null : (newValue) {
                              setState(() {
                                _selectedRestTime = newValue!;
                              });
                            },
                          ),
                        ),
                        Text(
                          _formatTime(_seconds),
                          style: TextStyle(
                            fontSize: 28, 
                            fontWeight: FontWeight.bold, 
                            fontFamily: 'monospace',
                            color: _seconds >= _selectedRestTime ? Colors.redAccent : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!_isTimerRunning)
                      IconButton.filled(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(40, 40),
                        ),
                      )
                    else
                      IconButton.filled(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(40, 40),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: _resetTimer,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _dynamicExercises.isEmpty
                ? const Center(child: Text('Este treino não tem exercícios.'))
                : ListView.builder(
                    itemCount: _dynamicExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _dynamicExercises[index];
                      final sets = _setsByExercise[exercise.id!] ?? [];

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: exercise.imageUrl!.startsWith('http')
                                            ? Image.network(
                                                exercise.imageUrl!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                                ),
                                              )
                                            : Image.file(
                                                File(exercise.imageUrl!),
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                                ),
                                              ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.name,
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        if (exercise.category != null)
                                          Text(
                                            exercise.category!,
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_fill, color: Colors.blueAccent),
                                      tooltip: 'Ver execução',
                                      onPressed: () => _launchVideo(exercise.videoUrl!),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                                    tooltip: 'Observações do treino',
                                    onPressed: () => _showExerciseNotesDialog(exercise),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.history, color: Colors.blueAccent),
                                    tooltip: 'Histórico de Cargas',
                                    onPressed: () => _showExerciseHistory(exercise),
                                  ),

                                ],
                              ),
                              if (exercise.workoutSpecificNotes != null && exercise.workoutSpecificNotes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                                  child: Text(
                                    'Obs: ${exercise.workoutSpecificNotes}',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade200, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              ...sets.asMap().entries.map((entry) {
                                int setIndex = entry.key;
                                ExerciseSet set = entry.value;
                                bool isCompleted = _completedSets[exercise.id!]![setIndex];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isCompleted ? Colors.green : Colors.grey.shade700,
                                        child: Text(
                                          '${setIndex + 1}', 
                                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: set.reps.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Reps',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            sets[setIndex] = ExerciseSet(
                                              reps: int.tryParse(val) ?? 0,
                                              weight: sets[setIndex].weight,
                                              exerciseId: exercise.id,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: set.weight.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Peso (kg)',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            sets[setIndex] = ExerciseSet(
                                              reps: sets[setIndex].reps,
                                              weight: double.tryParse(val) ?? 0.0,
                                              exerciseId: exercise.id,
                                            );
                                          },
                                        ),
                                      ),
                                      Checkbox(
                                        value: isCompleted,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          setState(() {
                                            _completedSets[exercise.id!]![setIndex] = val ?? false;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () {
                                          setState(() {
                                            sets.removeAt(setIndex);
                                            _completedSets[exercise.id!]!.removeAt(setIndex);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _addSet(exercise.id!),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar Série'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _showAddExerciseDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Adicionar Novo Exercício Hoje'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: ElevatedButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.check_circle),
              label: const Text('Concluir Treino', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
