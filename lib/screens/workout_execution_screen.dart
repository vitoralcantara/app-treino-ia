import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

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
          _setsByExercise[exercise.id!] = [
            ExerciseSet(reps: 10, weight: 0, exerciseId: exercise.id),
          ];
          _completedSets[exercise.id!] = [false];
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
    final imageUrlController = TextEditingController(); // Nova linha

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Exercício'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Categoria (Peito, Pernas...)')),
            TextField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL da Imagem (Opcional)')), // Novo campo
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
                  imageUrl: imageUrlController.text.isNotEmpty ? imageUrlController.text : null, // Nova propriedade
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Executando: ${widget.workout.name}'),
      ),
      body: Column(
        children: [
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
                                        child: Image.network(
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
                                  IconButton(
                                    icon: const Icon(Icons.history, color: Colors.blueAccent),
                                    tooltip: 'Histórico de Cargas',
                                    onPressed: () => _showExerciseHistory(exercise),
                                  ),
                                ],
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
