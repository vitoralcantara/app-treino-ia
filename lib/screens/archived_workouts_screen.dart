import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../providers/workout_provider.dart';

class ArchivedWorkoutsScreen extends ConsumerStatefulWidget {
  const ArchivedWorkoutsScreen({super.key});

  @override
  ConsumerState<ArchivedWorkoutsScreen> createState() => _ArchivedWorkoutsScreenState();
}

class _ArchivedWorkoutsScreenState extends ConsumerState<ArchivedWorkoutsScreen> {
  List<Workout> _archived = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    final archived = await ref.read(workoutListProvider.notifier).getArchivedWorkouts();
    if (mounted) {
      setState(() {
        _archived = archived;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos Anteriores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archived.isEmpty
              ? const Center(child: Text('Nenhum treino arquivado.'))
              : ListView.builder(
                  itemCount: _archived.length,
                  itemBuilder: (context, index) {
                    final workout = _archived[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(workout.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${workout.exercises.length} exercícios'),
                        trailing: TextButton.icon(
                          onPressed: () => _restoreWorkout(workout),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Retomar'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _restoreWorkout(Workout workout) async {
    await ref.read(workoutListProvider.notifier).toggleWorkoutActivity(workout.id!, true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Treino "${workout.name}" restaurado!')),
      );
      _loadArchived();
    }
  }
}
