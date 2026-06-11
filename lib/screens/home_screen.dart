import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../models/routine.dart';
import '../services/ai_prompt_helper.dart';
import '../providers/workout_provider.dart';
import '../services/backup_service.dart';
import 'workout_execution_screen.dart';
import 'workout_details_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkDisclaimer();
    _checkBackupReminder();
  }

  Future<void> _checkDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('disclaimer_accepted') ?? false;

    if (!accepted && mounted) {
      _showDisclaimerDialog();
    }
  }

  Future<void> _checkBackupReminder() async {
    final backupService = BackupService();
    if (await backupService.shouldShowBackupReminder()) {
      if (mounted) {
        _showBackupReminderDialog();
      }
    }
  }

  void _showBackupReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup_outlined, color: Colors.blue),
            SizedBox(width: 10),
            Text('Backup Mensal'),
          ],
        ),
        content: const Text(
          'Faz mais de um mês desde o seu último backup. Que tal salvar seus treinos e histórico agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lembrar Depois'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await BackupService().exportBackup();
            },
            child: const Text('Fazer Backup Agora'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Aviso Importante'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Os treinos gerados por esta inteligência artificial são apenas sugestões e não substituem o acompanhamento de um profissional de educação física ou médico.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'A prática de exercícios sem supervisão adequada pode causar lesões. Consulte um profissional antes de iniciar qualquer rotina sugerida.',
              ),
              SizedBox(height: 16),
              Text(
                'Ao prosseguir, você assume total responsabilidade pela execução dos exercícios e pelos riscos envolvidos.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('disclaimer_accepted', true);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eu entendo e aceito os riscos'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // Se o teclado estiver aberto, apenas fecha ele
        if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }

        // Caso contrário, se o sistema permitir, deixa fechar o app
        // No caso do HomeScreen que é a raiz, podemos opcionalmente confirmar saída
        // mas o pedido específico foi sobre o teclado.
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meu Treino'),
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  } else {
                    // Se não tiver teclado, o comportamento padrão do back button
                    // pode ser minimizar o app ou o que o SO decidir.
                  }
                },
              );
            },
          ),
        ),
        body: IndexedStack(
        index: _selectedIndex,
        children: const [
          WorkoutTab(),
          HistoryTab(),
          AiScreen(),
          ProfileScreen(),
        ],
      ),
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
            label: 'IA',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    ),
    );
  }
}

class WorkoutTab extends ConsumerWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutListProvider);
    final sessions = ref.watch(sessionListProvider);
    
    final totalExercises = workouts.fold<int>(0, (sum, w) => sum + w.exercises.length);

    // Sugestão de próximo treino
    Workout? nextWorkout;
    if (workouts.isNotEmpty) {
      if (sessions.isEmpty) {
        nextWorkout = workouts.first;
      } else {
        final lastSession = sessions.first;
        final lastWorkoutIndex = workouts.indexWhere((w) => w.id == lastSession.workoutId);
        if (lastWorkoutIndex != -1) {
          final nextIndex = (lastWorkoutIndex + 1) % workouts.length;
          nextWorkout = workouts[nextIndex];
        } else {
          nextWorkout = workouts.first;
        }
      }
    }

    // Progresso do Ciclo
    final progressFuture = ref.watch(routineProgressProvider);

    return Scaffold(
      body: workouts.isEmpty
          ? const Center(child: Text('Nenhum treino criado ainda.'))
          : SingleChildScrollView(
            child: Column(
                children: [
                  // Card de Progresso do Ciclo
                  progressFuture.when(
                    data: (data) {
                      if (data.isEmpty) return const SizedBox.shrink();
                      
                      final routine = data['routine'] as Routine;
                      final sessionCount = data['sessions'] as int;
                      final suggestedWeeks = data['suggested_weeks'] as int?;
                      
                      if (suggestedWeeks == null) return const SizedBox.shrink();

                      // Estimativa de 3 treinos/semana se a IA não especificou
                      final totalTarget = suggestedWeeks * 3;
                      final progress = (sessionCount / totalTarget).clamp(0.0, 1.0);
                      final isComplete = progress >= 1.0;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isComplete ? Colors.green.withValues(alpha: 0.5) : Colors.transparent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ciclo: ${routine.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        isComplete ? 'Ciclo Finalizado! 🎉' : 'Evolução do Ciclo',
                                        style: TextStyle(fontSize: 11, color: isComplete ? Colors.green : Colors.grey),
                                      ),
                                    ],
                                  ),
                                  if (isComplete)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Vá na aba IA e peça uma revisão do seu treino!')),
                                        );
                                      },
                                      icon: const Icon(Icons.psychology, size: 14),
                                      label: const Text('Revisar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 30),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: progress,
                                borderRadius: BorderRadius.circular(10),
                                minHeight: 6,
                                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(isComplete ? Colors.green : Colors.blue),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Treino $sessionCount de $totalTarget (Meta: $suggestedWeeks semanas)',
                                    style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                  ),
                                  InkWell(
                                    onTap: () => _showFrequencyDialog(context, ref, routine),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_month, size: 12, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getFrequencyLabel(routine),
                                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade500],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sua Rotina ABC',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Total de exercícios na semana',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$totalExercises',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (nextWorkout != null) ...[
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.next_plan, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sugestão para hoje:',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nextWorkout.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkoutExecutionScreen(workout: nextWorkout!),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade800,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Iniciar', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          'Meus Treinos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workouts.length,
                    itemBuilder: (context, index) {
                      final workout = workouts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            workout.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text('${workout.exercises.length} exercícios'),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                                tooltip: 'Editar',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WorkoutDetailsScreen(workoutId: workout.id!),
                                    ),
                                  );
                                },
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
                        ),
                      );
                    },
                  ),
                ],
              ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWorkoutDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getFrequencyLabel(Routine routine) {
    if (routine.frequencyType == null) return 'Agendar';
    switch (routine.frequencyType) {
      case 'daily': return 'Diário';
      case 'weekdays': return 'Dias Úteis';
      case 'weekly': return 'Semanal (${routine.frequencyValue ?? ""})';
      default: return 'Agendar';
    }
  }

  void _showFrequencyDialog(BuildContext context, WidgetRef ref, Routine routine) {
    showDialog(
      context: context,
      builder: (context) => _RoutineFrequencyDialog(routine: routine, ref: ref),
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

class _RoutineFrequencyDialog extends StatefulWidget {
  final Routine routine;
  final WidgetRef ref;

  const _RoutineFrequencyDialog({required this.routine, required this.ref});

  @override
  State<_RoutineFrequencyDialog> createState() => _RoutineFrequencyDialogState();
}

class _RoutineFrequencyDialogState extends State<_RoutineFrequencyDialog> {
  String? _selectedType;
  final List<String> _selectedDays = [];
  final List<String> _weekDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.routine.frequencyType;
    if (_selectedType == 'weekly' && widget.routine.frequencyValue != null) {
      _selectedDays.addAll(widget.routine.frequencyValue!.split(','));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Frequência do Treino'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            initialValue: _selectedType,
            hint: const Text('Selecione a frequência'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Diariamente')),
              DropdownMenuItem(value: 'weekdays', child: Text('Dias da Semana (Seg-Sex)')),
              DropdownMenuItem(value: 'weekly', child: Text('Semanal (Dias específicos)')),
            ],
            onChanged: (val) => setState(() => _selectedType = val),
          ),
          if (_selectedType == 'weekly') ...[
            const SizedBox(height: 16),
            const Text('Selecione os dias:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 4,
              children: _weekDays.map((day) => FilterChip(
                label: Text(day, style: const TextStyle(fontSize: 10)),
                selected: _selectedDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              )).toList(),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            String? value;
            if (_selectedType == 'weekly') {
              value = _selectedDays.join(',');
            }
            widget.ref.read(workoutListProvider.notifier).updateRoutineFrequency(widget.routine.id!, _selectedType, value);
            Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
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
      body: Column(
        children: [
          if (sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        const Text('Treinos Concluídos', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          '${sessions.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: sessions.isEmpty
                ? const Center(child: Text('Nenhum histórico registrado.'))
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        title: Text(session.workoutName),
                        subtitle: Text(
                          '${session.date.day.toString().padLeft(2, '0')}/${session.date.month.toString().padLeft(2, '0')}/${session.date.year} - ${session.sets.length} séries',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
