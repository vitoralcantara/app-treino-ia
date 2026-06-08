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

  @override
  void initState() {
    super.initState();
    for (var exercise in widget.workout.exercises) {
      _setsByExercise[exercise.id!] = [];
    }
  }

  void _addSet(int exerciseId) {
    setState(() {
      _setsByExercise[exerciseId]!.add(
        ExerciseSet(reps: 10, weight: 0, exerciseId: exerciseId),
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
                        ...sets.asMap().entries.map((entry) {
                          int setIndex = entry.key;
                          ExerciseSet set = entry.value;
                          return Row(
                            children: [
                              Text('Série ${setIndex + 1}: '),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Reps'),
                                  onChanged: (val) {
                                    sets[setIndex] = ExerciseSet(
                                      reps: int.tryParse(val) ?? 0,
                                      weight: set.weight,
                                      exerciseId: exercise.id,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                                  onChanged: (val) {
                                    sets[setIndex] = ExerciseSet(
                                      reps: set.reps,
                                      weight: double.tryParse(val) ?? 0.0,
                                      exerciseId: exercise.id,
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    sets.removeAt(setIndex);
                                  });
                                },
                              ),
                            ],
                          );
                        }),
                        TextButton.icon(
                          onPressed: () => _addSet(exercise.id!),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Série'),
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
