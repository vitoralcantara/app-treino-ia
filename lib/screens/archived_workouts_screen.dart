import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine.dart';
import '../providers/workout_provider.dart';

class ArchivedWorkoutsScreen extends ConsumerStatefulWidget {
  const ArchivedWorkoutsScreen({super.key});

  @override
  ConsumerState<ArchivedWorkoutsScreen> createState() => _ArchivedWorkoutsScreenState();
}

class _ArchivedWorkoutsScreenState extends ConsumerState<ArchivedWorkoutsScreen> {
  List<Routine> _archivedRoutines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    final archived = await ref.read(workoutListProvider.notifier).getArchivedRoutines();
    if (mounted) {
      setState(() {
        _archivedRoutines = archived;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotinas Anteriores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedRoutines.isEmpty
              ? const Center(child: Text('Nenhuma rotina arquivada.'))
              : ListView.builder(
                  itemCount: _archivedRoutines.length,
                  itemBuilder: (context, index) {
                    final routine = _archivedRoutines[index];
                    final totalExercises = routine.workouts.fold(0, (sum, w) => sum + w.exercises.length);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ExpansionTile(
                        title: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${routine.workouts.length} treinos • $totalExercises exercícios • ${_formatDate(routine.createdAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _restoreRoutine(routine),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Retomar Esta'),
                        ),
                        children: routine.workouts.map((w) => ListTile(
                          dense: true,
                          title: Text(w.name),
                          subtitle: Text('${w.exercises.length} exercícios'),
                          leading: const Icon(Icons.fitness_center, size: 18),
                        )).toList(),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _restoreRoutine(Routine routine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar Rotina?'),
        content: Text('Sua rotina atual será arquivada e a rotina "${routine.name}" será ativada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim, trocar')),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(workoutListProvider.notifier).activateRoutine(routine.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotina "${routine.name}" agora é a ativa!')),
        );
        _loadArchived();
      }
    }
  }
}
