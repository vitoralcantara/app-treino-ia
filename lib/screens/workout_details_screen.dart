import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

class WorkoutDetailsScreen extends ConsumerWidget {
  final int workoutId;

  const WorkoutDetailsScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutListProvider);
    final workout = workouts.firstWhere((w) => w.id == workoutId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar: ${workout.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () => _confirmDeleteWorkout(context, ref, workout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercícios (${workout.exercises.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddExerciseDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: workout.exercises.isEmpty
                ? const Center(child: Text('Nenhum exercício neste treino.'))
                : ListView.builder(
                    itemCount: workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = workout.exercises[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(exercise.category ?? 'Geral'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () {
                            ref.read(workoutListProvider.notifier).removeExerciseFromWorkout(
                                  workoutId,
                                  exercise.id!,
                                );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWorkout(BuildContext context, WidgetRef ref, Workout workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Treino'),
        content: Text('Tem certeza que deseja excluir o treino "${workout.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(workoutListProvider.notifier).deleteWorkout(workout.id!);
              Navigator.pop(context); // close dialog
              if (context.mounted) Navigator.pop(context); // close screen
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Escolha um Exercício', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
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
                              onTap: () => _showCreateCustomExerciseDialog(context, ref),
                            );
                          }
                          final exercise = exercises[index];
                          return ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(exercise.category ?? ''),
                            trailing: const Icon(Icons.add),
                            onTap: () {
                              ref.read(workoutListProvider.notifier).addExerciseToWorkout(workoutId, exercise.id!);
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
      ),
    );
  }

  void _showCreateCustomExerciseDialog(BuildContext context, WidgetRef ref) {
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
                  if (context.mounted) Navigator.pop(context); // close this dialog
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
