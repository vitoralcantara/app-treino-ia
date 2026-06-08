import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import '../services/ai_prompt_helper.dart';
import '../providers/workout_provider.dart';
import 'workout_execution_screen.dart';
import 'workout_details_screen.dart';
import 'ai_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    WorkoutTab(),
    HistoryTab(),
    AiScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Treino'),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Treinos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology),
            label: 'Gemini IA',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

class WorkoutTab extends ConsumerWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutListProvider);

    return Scaffold(
      body: workouts.isEmpty
          ? const Center(child: Text('Nenhum treino criado ainda.'))
          : ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Text('${workout.exercises.length} exercícios'),
                  leading: IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    tooltip: 'Exportar para IA',
                    onPressed: () {
                      final prompt = AiPromptHelper.generateExportWorkoutPrompt(workout);
                      Clipboard.setData(ClipboardData(text: prompt));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Treino copiado para levar ao Gemini!')),
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutDetailsScreen(workoutId: workout.id!),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.play_arrow),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutExecutionScreen(workout: workout),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement manual workout creation
          // For now, we rely on AI to create them or a simple dialog
          _showAddWorkoutDialog(context, ref);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWorkoutDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Treino'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nome do treino (ex: Treino A)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // For simplicity, starting with an empty workout
                ref.read(workoutListProvider.notifier).addWorkout(
                  Workout(name: controller.text, exercises: []),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: sessions.isEmpty
          ? null
          : AppBar(
              title: const Text('Histórico', style: TextStyle(fontSize: 16)),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    final prompt = AiPromptHelper.generateExportHistoryPrompt(sessions);
                    Clipboard.setData(ClipboardData(text: prompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Histórico completo copiado para o Gemini!')),
                    );
                  },
                  icon: const Icon(Icons.psychology),
                  label: const Text('Exportar para IA'),
                ),
              ],
            ),
      body: sessions.isEmpty
          ? const Center(child: Text('Nenhum histórico registrado.'))
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  title: Text(session.workoutName),
                  subtitle: Text(
                    '${session.date.day}/${session.date.month}/${session.date.year} - ${session.sets.length} séries',
                  ),
                );
              },
            ),
    );
  }
}
