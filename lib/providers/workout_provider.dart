import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/routine.dart';
import 'backup_provider.dart';
import '../services/notification_service.dart';

final databaseProvider = Provider((ref) => DatabaseHelper.instance);

class WorkoutListNotifier extends Notifier<List<Workout>> {
  @override
  List<Workout> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    state = await db.getAllWorkouts(activeOnly: true);
  }

  void _triggerCloudBackup() {
    // Tenta fazer sincronização automática respeitando as configurações do usuário
    ref.read(backupProvider.notifier).triggerAutoSync();
  }

  Future<void> archiveCurrentRoutine() async {
    final db = ref.read(databaseProvider);
    await db.archiveCurrentRoutine();
    await _load();
    _triggerCloudBackup();
  }

  Future<void> activateRoutine(int routineId) async {
    final db = ref.read(databaseProvider);
    await db.activateRoutine(routineId);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> updateRoutineFrequency(int routineId, String? type, String? value) async {
    final db = ref.read(databaseProvider);
    await db.updateRoutineFrequency(routineId, type, value);
    ref.invalidate(routineProgressProvider); // Força atualização da UI que depende do progresso da rotina
    await _load();
    _triggerCloudBackup();
  }

  Future<List<Routine>> getArchivedRoutines() async {
    final db = ref.read(databaseProvider);
    return await db.getArchivedRoutines();
  }

  Future<Map<String, dynamic>> getRoutineProgress() async {
    final db = ref.read(databaseProvider);
    final active = await db.getActiveRoutine();
    if (active == null) return {};

    final sessionCount = await db.getSessionsCountForRoutine(active.id!);
    return {
      'routine': active,
      'sessions': sessionCount,
      'suggested_weeks': active.suggestedDurationWeeks,
    };
  }

  Future<void> addWorkout(Workout workout) async {
    final db = ref.read(databaseProvider);
    await db.createWorkout(workout);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> deleteWorkout(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteWorkout(id);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = ref.read(databaseProvider);
    await db.addExerciseToWorkout(workoutId, exerciseId);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> updateExerciseNotesInWorkout(int workoutId, int exerciseId, String notes) async {
    final db = ref.read(databaseProvider);
    await db.updateExerciseNotesInWorkout(workoutId, exerciseId, notes);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> removeExerciseFromWorkout(int workoutId, int exerciseId) async {
    final db = ref.read(databaseProvider);
    await db.removeExerciseFromWorkout(workoutId, exerciseId);
    await _load();
    _triggerCloudBackup();
  }
}

final workoutListProvider = NotifierProvider<WorkoutListNotifier, List<Workout>>(WorkoutListNotifier.new);

class ExerciseListNotifier extends Notifier<AsyncValue<List<Exercise>>> {
  @override
  AsyncValue<List<Exercise>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    try {
      final list = await db.getAllExercises();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _triggerCloudBackup() {
    // Tenta fazer sincronização automática respeitando as configurações do usuário
    ref.read(backupProvider.notifier).triggerAutoSync();
  }

  Future<void> addExercise(Exercise exercise) async {
    final db = ref.read(databaseProvider);
    await db.createExercise(exercise);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = ref.read(databaseProvider);
    await db.updateExercise(exercise);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> toggleExerciseAvailability(int id, bool isAvailable) async {
    final db = ref.read(databaseProvider);
    await db.toggleExerciseAvailability(id, isAvailable);
    await _load();
    _triggerCloudBackup();
  }

  Future<void> deleteExercise(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteExercise(id);
    await _load();
    _triggerCloudBackup();
  }
}

final exerciseListProvider = NotifierProvider<ExerciseListNotifier, AsyncValue<List<Exercise>>>(ExerciseListNotifier.new);

class SessionListNotifier extends Notifier<List<WorkoutSession>> {
  @override
  List<WorkoutSession> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    state = await db.getAllSessions();
  }

  void _triggerCloudBackup() {
    // Tenta fazer sincronização automática respeitando as configurações do usuário
    ref.read(backupProvider.notifier).triggerAutoSync();
  }

  Future<void> addSession(WorkoutSession session) async {
    final db = ref.read(databaseProvider);
    await db.createWorkoutSession(session);
    await _load();
    _triggerCloudBackup();
  }
}

final sessionListProvider = NotifierProvider<SessionListNotifier, List<WorkoutSession>>(SessionListNotifier.new);

class WorkoutTimerNotifier extends Notifier<WorkoutTimerState> {
  Timer? _timer;
  static const String _restTimeKey = 'selected_rest_time';

  @override
  WorkoutTimerState build() {
    _loadRestTimePreference();
    return WorkoutTimerState.initial();
  }

  Future<void> _loadRestTimePreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(selectedRestTime: prefs.getInt(_restTimeKey) ?? 60);
  }

  void startTimer() async {
    if (state.isTimerRunning) return;
    
    // Solicitar permissão de notificação para Android 13+
    final notificationService = NotificationService();
    await notificationService.requestNotificationPermission();
    
    state = state.copyWith(
      isTimerRunning: true,
      timerStartTime: DateTime.now().subtract(Duration(seconds: state.seconds)),
    );

    // Mostrar notificação em tempo real com o countdown
    final remainingTime = state.selectedRestTime - state.seconds;
    notificationService.showActiveTimerNotification(remainingTime, state.selectedRestTime);

    // Agendar notificação para o fim do tempo selecionado
    notificationService.scheduleRestNotification(state.selectedRestTime - state.seconds > 0 ? state.selectedRestTime - state.seconds : state.selectedRestTime);

    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newSeconds = state.seconds + 1;
      final remainingTime = state.selectedRestTime - newSeconds;

      // Atualizar notificação em tempo real
      if (remainingTime > 0) {
        NotificationService().updateTimerNotification(remainingTime);
      }

      if (newSeconds >= state.selectedRestTime) {
        pauseTimer();
      } else {
        state = state.copyWith(seconds: newSeconds);
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    state = state.copyWith(
      isTimerRunning: false,
      timerStartTime: null,
    );
  }

  void resetTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    state = WorkoutTimerState.initial().copyWith(selectedRestTime: state.selectedRestTime);
  }

  void updateRestTime(int newRestTime) {
    state = state.copyWith(selectedRestTime: newRestTime);
  }

  void handleAppLifecycleResumed() {
    if (state.isTimerRunning && state.timerStartTime != null) {
      // Recalcular o tempo decorrido enquanto o app estava em segundo plano
      final elapsedSeconds = DateTime.now().difference(state.timerStartTime!).inSeconds;
      state = state.copyWith(seconds: elapsedSeconds);
      final remainingTime = state.selectedRestTime - elapsedSeconds;

      // Atualizar notificação com o tempo recalculado
      if (remainingTime > 0) {
        NotificationService().updateTimerNotification(remainingTime);
      }

      if (elapsedSeconds >= state.selectedRestTime) {
        pauseTimer();
      } else {
        // Reiniciar o timer com o tempo atualizado
        _startPeriodicTimer();
      }
    }
  }
}

class WorkoutTimerState {
  final int seconds;
  final bool isTimerRunning;
  final int selectedRestTime;
  final DateTime? timerStartTime;

  WorkoutTimerState({
    required this.seconds,
    required this.isTimerRunning,
    required this.selectedRestTime,
    this.timerStartTime,
  });

  factory WorkoutTimerState.initial() {
    return WorkoutTimerState(
      seconds: 0,
      isTimerRunning: false,
      selectedRestTime: 60,
      timerStartTime: null,
    );
  }

  WorkoutTimerState copyWith({
    int? seconds,
    bool? isTimerRunning,
    int? selectedRestTime,
    DateTime? timerStartTime,
  }) {
    return WorkoutTimerState(
      seconds: seconds ?? this.seconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      selectedRestTime: selectedRestTime ?? this.selectedRestTime,
      timerStartTime: timerStartTime ?? this.timerStartTime,
    );
  }
}

final workoutTimerProvider = NotifierProvider<WorkoutTimerNotifier, WorkoutTimerState>(WorkoutTimerNotifier.new);

final routineProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Observar mudanças no histórico para atualizar o progresso automaticamente
  ref.watch(sessionListProvider);
  return await ref.read(workoutListProvider.notifier).getRoutineProgress();
});
