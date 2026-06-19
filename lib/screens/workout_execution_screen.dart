import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

class WorkoutExecutionScreen extends ConsumerStatefulWidget {
  final Workout workout;
  final bool isViewingOnly;

  const WorkoutExecutionScreen({
    super.key, 
    required this.workout,
    this.isViewingOnly = false,
  });

  @override
  ConsumerState<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends ConsumerState<WorkoutExecutionScreen> with WidgetsBindingObserver {
  final Map<int, List<ExerciseSet>> _setsByExercise = {};
  final Map<int, List<bool>> _completedSets = {}; // Controla quais séries foram concluídas
  final List<Exercise> _dynamicExercises = []; // Exercícios adicionados na hora
  bool _initialized = false;
  late bool _isViewingMode;
  
  // Auto-save de pesos
  Timer? _autoSaveTimer;
  static const Duration _autoSaveDebounce = Duration(milliseconds: 1000);
  final Set<int> _pendingExercisesToSave = {};

  @override
  void initState() {
    super.initState();
    _isViewingMode = widget.isViewingOnly;
    WidgetsBinding.instance.addObserver(this);
    
    if (!_isViewingMode) {
      _setActiveWorkout();
    }
  }

  Future<void> _setActiveWorkout() async {
    if (widget.workout.id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_workout_id', widget.workout.id!);
    }
  }

  Future<void> _clearActiveWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_workout_id');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    
    // Tenta salvar pesos pendentes antes de fechar
    if (_pendingExercisesToSave.isNotEmpty) {
      _savePendingWeights();
    }
    
    // Só limpa se estivéssemos no modo de execução e o usuário saiu (cancelou)
    if (!_isViewingMode) {
      _clearActiveWorkout();
    }
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isViewingMode) {
      ref.read(workoutTimerProvider.notifier).handleAppLifecycleResumed();
    }
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

  void _loadLastSessionData() async {
    final sessions = ref.read(sessionListProvider);
    final db = ref.read(databaseProvider);
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

    final exerciseIds = _dynamicExercises.map((e) => e.id!).toList();
    
    // Carregar todos os pesos padrão de uma vez para performance
    final allDefaultWeights = await db.getAllExerciseDefaultWeights(exerciseIds);

    // Inicializar todos os exercícios
    for (var exercise in _dynamicExercises) {
      final exerciseId = exercise.id!;
      
      // 1. Tentar pesos padrão (auto-salvos)
      if (allDefaultWeights.containsKey(exerciseId)) {
        _setsByExercise[exerciseId] = allDefaultWeights[exerciseId]!;
        _completedSets[exerciseId] = List.generate(_setsByExercise[exerciseId]!.length, (_) => false);
        continue;
      }

      // 2. Tentar sessão anterior
      final previousSets = lastSession.sets.where((s) => s.exerciseId == exerciseId).toList();
      if (previousSets.isNotEmpty) {
        _setsByExercise[exerciseId] = previousSets.map((s) => ExerciseSet(
          reps: s.reps,
          weight: s.weight,
          exerciseId: exerciseId,
          technique: s.technique,
        )).toList();
        _completedSets[exerciseId] = List.generate(previousSets.length, (_) => false);
        continue;
      }

      // 3. Usar sugestão da IA ou padrão fixo
      final suggestedSets = exercise.suggestedSets ?? 3;
      final suggestedReps = exercise.suggestedReps ?? 10;
      final suggestedList = exercise.suggestedRepsList;

      _setsByExercise[exerciseId] = List.generate(
        suggestedSets,
        (i) {
          int reps = suggestedReps;
          if (suggestedList != null && i < suggestedList.length) {
            reps = suggestedList[i];
          }
          return ExerciseSet(
            reps: reps,
            weight: '0',
            exerciseId: exerciseId,
            technique: exercise.suggestedTechnique,
          );
        },
      );
      _completedSets[exerciseId] = List.generate(suggestedSets, (_) => false);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _addSet(int exerciseId) {
    if (_isViewingMode) return; // Não permitir alterações no modo de visualização

    setState(() {
      // Garantir que o map tenha a chave do exercício
      if (!_setsByExercise.containsKey(exerciseId)) {
        _setsByExercise[exerciseId] = [];
        _completedSets[exerciseId] = [];
      }
      
      final sets = _setsByExercise[exerciseId]!;
      
      // Se não houver séries, cria a primeira com valores padrão
      if (sets.isEmpty) {
        _setsByExercise[exerciseId]!.add(
          ExerciseSet(
            reps: 10, // Valor padrão
            weight: '0',
            exerciseId: exerciseId,
            technique: null,
          ),
        );
        _completedSets[exerciseId]!.add(false);
      } else {
        // Se houver séries, copia da última
        final lastSet = sets.last;
        _setsByExercise[exerciseId]!.add(
          ExerciseSet(
            reps: lastSet.reps,
            weight: '0', // Nova série começa sem peso
            exerciseId: exerciseId,
            technique: lastSet.technique,
          ),
        );
        _completedSets[exerciseId]!.add(false);
      }
    });
    
    // Agendar auto-save ao adicionar série
    _scheduleAutoSave(exerciseId);
  }

  void _scheduleAutoSave(int exerciseId) {
    if (_isViewingMode) return;
    _pendingExercisesToSave.add(exerciseId);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, () {
      _savePendingWeights();
    });
  }

  Future<void> _savePendingWeights() async {
    if (_pendingExercisesToSave.isEmpty || _isViewingMode) return;
    
    try {
      final db = ref.read(databaseProvider);
      final exerciseIdsToSave = List<int>.from(_pendingExercisesToSave);
      _pendingExercisesToSave.clear();

      for (var exerciseId in exerciseIdsToSave) {
        final sets = _setsByExercise[exerciseId];
        if (sets != null && sets.isNotEmpty) {
          await db.saveExerciseDefaultWeights(exerciseId, sets);
        }
      }
    } catch (e) {
      // Erro silencioso no auto-save
      debugPrint('Erro no auto-save: \$e');
    }
  }

  void _finishWorkout() async {
    if (_isViewingMode) return;

    final List<ExerciseSet> completedSetsList = [];

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

    // Salvar qualquer coisa pendente antes de finalizar
    await _savePendingWeights();

    final session = WorkoutSession(
      workoutId: widget.workout.id!,
      workoutName: widget.workout.name,
      date: DateTime.now(),
      sets: completedSetsList,
    );

    await ref.read(sessionListProvider.notifier).addSession(session);

    // Salvar pesos padrão para cada exercício que teve séries concluídas
    final db = ref.read(databaseProvider);
    for (var exercise in _dynamicExercises) {
      final exerciseId = exercise.id!;
      final sets = _setsByExercise[exerciseId]!;
      final completedStatus = _completedSets[exerciseId]!;

      // Verificar se houve pelo menos uma série concluída para este exercício
      final hasCompletedSets = completedStatus.any((completed) => completed);
      if (hasCompletedSets) {
        await db.saveExerciseDefaultWeights(exerciseId, sets);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino concluído e salvo no histórico!')),
      );
      // Resetar o timer quando o treino é finalizado
      ref.read(workoutTimerProvider.notifier).resetTimer();
      _clearActiveWorkout(); // Remove o treino ativo pois já acabou
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
                        final tech = record['technique'] as String?;

                        return ListTile(
                          leading: const Icon(Icons.fitness_center),
                          title: Text('$weight kg x $reps reps'),
                          subtitle: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${tech != null ? "($tech)" : ""}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseInfo(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (exercise.category != null)
                Text(
                  exercise.category!,
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                ),
              const Divider(height: 32),
              if (exercise.instructions != null && exercise.instructions!.isNotEmpty) ...[
                const Text(
                  'Instruções:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(exercise.instructions!),
                const SizedBox(height: 24),
              ],
              if (exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty) ...[
                const Text(
                  'Demonstração em Vídeo:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchVideo(exercise.videoUrl!),
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Abrir Vídeo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) ...[
                const Text(
                  'Referência Visual:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: exercise.imageUrl!.startsWith('http')
                      ? Image.network(exercise.imageUrl!)
                      : Image.file(File(exercise.imageUrl!)),
                ),
              ],
            ],
          ),
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
              if (context.mounted) {
                setState(() {
                  final index = _dynamicExercises.indexWhere((e) => e.id == exercise.id);
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
                      groupId: exercise.groupId,
                      suggestedTechnique: exercise.suggestedTechnique,
                    );
                  }
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _toggleTechnique(int exerciseId, int setIndex) {
    if (_isViewingMode) return;

    // Garantir que o map tenha a chave do exercício
    if (!_setsByExercise.containsKey(exerciseId)) {
      return;
    }
    
    final sets = _setsByExercise[exerciseId]!;
    if (setIndex >= sets.length) {
      return;
    }
    
    final currentTech = sets[setIndex].technique;
    String? nextTech;
    
    if (currentTech == null) {
      nextTech = 'drop_set';
    } else if (currentTech == 'drop_set') {
      nextTech = 'rest_pause';
    } else {
      nextTech = null;
    }

    setState(() {
      sets[setIndex] = ExerciseSet(
        reps: sets[setIndex].reps,
        weight: sets[setIndex].weight,
        exerciseId: exerciseId,
        technique: nextTech,
      );
    });

    // Agendar auto-save ao alterar técnica
    _scheduleAutoSave(exerciseId);

    if (nextTech != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Técnica: ${nextTech == 'drop_set' ? 'Drop Set' : 'Rest Pause'} aplicada!'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  IconData _getTechniqueIcon(String technique) {
    if (technique == 'drop_set') return Icons.arrow_downward;
    if (technique == 'rest_pause') return Icons.timer_outlined;
    return Icons.help;
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(workoutTimerProvider);
    
    // Agrupar exercícios por groupId para exibição
    final List<List<Exercise>> groupedExercises = [];
    String? currentGroupId;
    List<Exercise> currentGroup = [];

    for (var ex in _dynamicExercises) {
      if (ex.groupId != null && ex.groupId!.isNotEmpty) {
        if (ex.groupId == currentGroupId) {
          currentGroup.add(ex);
        } else {
          if (currentGroup.isNotEmpty) groupedExercises.add(List.from(currentGroup));
          currentGroup = [ex];
          currentGroupId = ex.groupId;
        }
      } else {
        if (currentGroup.isNotEmpty) groupedExercises.add(List.from(currentGroup));
        groupedExercises.add([ex]);
        currentGroup = [];
        currentGroupId = null;
      }
    }
    if (currentGroup.isNotEmpty) groupedExercises.add(currentGroup);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _pendingExercisesToSave.isNotEmpty && !_isViewingMode) {
          _savePendingWeights();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isViewingMode ? 'Visualizando: ${widget.workout.name}' : 'Executando: ${widget.workout.name}'),
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
                              value: timerState.selectedRestTime,
                              isDense: true,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              items: [30, 45, 60, 90, 120].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('${value}s DESCANSO'),
                                );
                              }).toList(),
                              onChanged: (timerState.isTimerRunning || _isViewingMode) ? null : (newValue) async {
                                if (newValue != null) {
                                  ref.read(workoutTimerProvider.notifier).updateRestTime(newValue);
                                  // Salvar preferência
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setInt('selected_rest_time', newValue);
                                }
                              },
                            ),
                          ),
                          Text(
                            _formatTime(timerState.seconds),
                            style: TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold, 
                              fontFamily: 'monospace',
                              color: timerState.seconds >= timerState.selectedRestTime ? Colors.redAccent : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!timerState.isTimerRunning)
                        IconButton.filled(
                          onPressed: _isViewingMode ? null : () => ref.read(workoutTimerProvider.notifier).startTimer(),
                          icon: const Icon(Icons.play_arrow),
                          style: IconButton.styleFrom(
                            backgroundColor: _isViewingMode ? Colors.grey : Colors.green,
                            minimumSize: const Size(40, 40),
                          ),
                        )
                      else
                        IconButton.filled(
                          onPressed: () => ref.read(workoutTimerProvider.notifier).pauseTimer(),
                          icon: const Icon(Icons.pause),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        onPressed: _isViewingMode ? null : () => ref.read(workoutTimerProvider.notifier).resetTimer(),
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
                      itemCount: groupedExercises.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groupedExercises[groupIndex];
                        final isSuperSet = group.length > 1;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: isSuperSet ? BoxDecoration(
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ) : null,
                          child: Column(
                            children: [
                              if (isSuperSet)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: const BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                                  ),
                                  child: Text(
                                    group.length == 2 ? 'BI-SET' : (group.length == 3 ? 'TRI-SET' : 'SUPER SÉRIE'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ...group.map((exercise) {
                                final sets = _setsByExercise[exercise.id!] ?? [];
                                return Card(
                                  margin: EdgeInsets.all(isSuperSet ? 8 : 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
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
                                              icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
                                              tooltip: 'Instruções',
                                              onPressed: () => _showExerciseInfo(exercise),
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
                                        // Cabeçalho das colunas
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 28, child: Text('Série', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                              const SizedBox(width: 8),
                                              const SizedBox(width: 65, child: Text('Reps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                              const SizedBox(width: 8),
                                              const Expanded(child: Text('Peso (kg)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                              const SizedBox(width: 8),
                                              const SizedBox(width: 48, child: Text('Feito', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        const SizedBox(height: 4),
                                        ...sets.asMap().entries.map((entry) {
                                          int setIndex = entry.key;
                                          ExerciseSet set = entry.value;
                                          bool isCompleted = _completedSets[exercise.id!]![setIndex];

                                          return GestureDetector(
                                            onLongPress: _isViewingMode ? null : () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Remover Série'),
                                                  content: const Text('Deseja realmente remover esta série?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                      child: const Text('Remover'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                setState(() {
                                                  sets.removeAt(setIndex);
                                                  _completedSets[exercise.id!]!.removeAt(setIndex);
                                                });
                                                _scheduleAutoSave(exercise.id!);
                                              }
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                                              margin: const EdgeInsets.symmetric(vertical: 2.0),
                                              child: Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: _isViewingMode ? null : () => _toggleTechnique(exercise.id!, setIndex),
                                                    child: CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: isCompleted ? Colors.green : Colors.grey.shade700,
                                                      child: set.technique == null
                                                        ? Text('${setIndex + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))
                                                        : Icon(_getTechniqueIcon(set.technique!), size: 14, color: Colors.white),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 65,
                                                    child: TextFormField(
                                                      initialValue: set.reps.toString(),
                                                      keyboardType: TextInputType.number,
                                                      enabled: !_isViewingMode,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Reps',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      ),
                                                      onChanged: (val) {
                                                        sets[setIndex] = ExerciseSet(
                                                          reps: int.tryParse(val) ?? 0,
                                                          weight: sets[setIndex].weight,
                                                          exerciseId: exercise.id,
                                                          technique: sets[setIndex].technique,
                                                        );
                                                        // Agendar auto-save
                                                        _scheduleAutoSave(exercise.id!);
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextFormField(
                                                      initialValue: set.weight == '0' ? '' : set.weight,
                                                      keyboardType: TextInputType.text,
                                                      enabled: !_isViewingMode,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Peso (kg)',
                                                        hintText: '00',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      ),
                                                      onChanged: (val) {
                                                        sets[setIndex] = ExerciseSet(
                                                          reps: sets[setIndex].reps,
                                                          weight: val.isEmpty ? '0' : val,
                                                          exerciseId: exercise.id,
                                                          technique: sets[setIndex].technique,
                                                        );
                                                        // Agendar auto-save dos pesos
                                                        _scheduleAutoSave(exercise.id!);
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 48,
                                                    child: Checkbox(
                                                      value: isCompleted,
                                                      onChanged: _isViewingMode ? null : (val) {
                                                        setState(() {
                                                          _completedSets[exercise.id!]![setIndex] = val ?? false;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                        if (!_isViewingMode)
                                          TextButton.icon(
                                            onPressed: () => _addSet(exercise.id!),
                                            icon: const Icon(Icons.add),
                                            label: const Text('Adicionar Série'),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isViewingMode
                  ? ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isViewingMode = false;
                        });
                        _setActiveWorkout();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Treino iniciado!')),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar Treino'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _finishWorkout,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Finalizar Treino'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
