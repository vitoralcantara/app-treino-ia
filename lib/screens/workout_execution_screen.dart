import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';
import '../providers/workout_provider.dart';

class WorkoutExecutionScreen extends ConsumerStatefulWidget {
  final Workout workout;

  const WorkoutExecutionScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends ConsumerState<WorkoutExecutionScreen> {
  final Map<int, List<ExerciseSet>> _setsByExercise = {};
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
      for (var exercise in widget.workout.exercises) {
        // Buscar séries desta última sessão para este exercício
        final previousSets = lastSession.sets.where((s) => s.exerciseId == exercise.id).toList();
        
        if (previousSets.isNotEmpty) {
          // Se houver histórico, preenchemos com os valores anteriores
          _setsByExercise[exercise.id!] = previousSets.map((s) => ExerciseSet(
            reps: s.reps,
            weight: s.weight,
            exerciseId: exercise.id,
          )).toList();
        } else {
          // Se não houver, começa com uma série padrão
          _setsByExercise[exercise.id!] = [
            ExerciseSet(reps: 10, weight: 0, exerciseId: exercise.id),
          ];
        }
      }
    });
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
    });
  }

  void _finishWorkout() async {
    final List<ExerciseSet> allSets = [];
    _setsByExercise.forEach((exerciseId, sets) {
      allSets.addAll(sets);
    });

    if (allSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registre pelo menos uma série!')),
      );
      return;
    }

    final session = WorkoutSession(
      workoutId: widget.workout.id!,
      workoutName: widget.workout.name,
      date: DateTime.now(),
      sets: allSets,
    );

    await ref.read(sessionListProvider.notifier).addSession(session);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Executando: ${widget.workout.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _finishWorkout,
          ),
        ],
      ),
      body: widget.workout.exercises.isEmpty
          ? const Center(child: Text('Este treino não tem exercícios.'))
          : ListView.builder(
              itemCount: widget.workout.exercises.length,
              itemBuilder: (context, index) {
                final exercise = widget.workout.exercises[index];
                final sets = _setsByExercise[exercise.id!] ?? [];

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...sets.asMap().entries.map((entry) {
                          int setIndex = entry.key;
                          ExerciseSet set = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  child: Text('${setIndex + 1}', style: const TextStyle(fontSize: 12)),
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
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      sets.removeAt(setIndex);
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
    );
  }
}
