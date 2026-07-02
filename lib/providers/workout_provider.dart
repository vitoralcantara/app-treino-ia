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
import '../services/routine_export_service.dart';

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

  Future<void> exportActiveRoutineAsTxt() async {
    final db = ref.read(databaseProvider);
    final fullRoutine = await db.getActiveRoutine(includeWorkouts: true);
    if (fullRoutine != null) {
      await RoutineExportService.exportRoutineAsTxt(fullRoutine);
    }
  }

  Future<void> exportActiveRoutineAsDoc() async {
    final db = ref.read(databaseProvider);
    final fullRoutine = await db.getActiveRoutine(includeWorkouts: true);
    if (fullRoutine != null) {
      await RoutineExportService.exportRoutineAsDoc(fullRoutine);
    }
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

  Future<void> toggleWorkoutActivity(int id, bool isActive) async {
    final db = ref.read(databaseProvider);
    await db.toggleWorkoutActivity(id, isActive);
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
    
    final int initialSeconds = state.seconds > 0 ? state.seconds : state.selectedRestTime;
    final DateTime now = DateTime.now();
    final DateTime target = now.add(Duration(seconds: initialSeconds));
    
    state = state.copyWith(
      isTimerRunning: true,
      seconds: initialSeconds,
      targetExpiryTime: target,
    );

    // Mostrar notificação em tempo real com o countdown
    notificationService.showActiveTimerNotification(initialSeconds, state.selectedRestTime);

    // Agendar notificação para o fim do tempo selecionado
    notificationService.scheduleRestNotification(initialSeconds);

    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.targetExpiryTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final difference = state.targetExpiryTime!.difference(now).inSeconds;
      final int remaining = difference > 0 ? difference : 0;

      // Atualizar notificação em tempo real
      if (remaining > 0) {
        NotificationService().updateTimerNotification(remaining);
      }

      if (remaining <= 0) {
        pauseTimer();
        state = state.copyWith(seconds: 0);
      } else {
        state = state.copyWith(seconds: remaining);
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    state = state.copyWith(
      isTimerRunning: false,
      targetExpiryTime: null,
    );
  }

  void resetTimer() {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    state = WorkoutTimerState.initial().copyWith(
      selectedRestTime: state.selectedRestTime,
      seconds: state.selectedRestTime, // Reset para o tempo padrão
    );
  }

  void restartAndStartTimer() async {
    _timer?.cancel();
    NotificationService().cancelAllNotifications();
    
    // Solicitar permissão de notificação para Android 13+
    final notificationService = NotificationService();
    await notificationService.requestNotificationPermission();
    
    final DateTime now = DateTime.now();
    final DateTime target = now.add(Duration(seconds: state.selectedRestTime));

    state = state.copyWith(
      isTimerRunning: true,
      seconds: state.selectedRestTime,
      targetExpiryTime: target,
    );
    
    // Mostrar notificação em tempo real com o countdown
    notificationService.showActiveTimerNotification(state.selectedRestTime, state.selectedRestTime);

    // Agendar notificação para o fim do tempo selecionado
    notificationService.scheduleRestNotification(state.selectedRestTime);

    _startPeriodicTimer();
  }

  void updateRestTime(int newRestTime) {
    // Se o timer não estiver rodando, atualiza também o display para o novo tempo
    if (!state.isTimerRunning) {
      state = state.copyWith(
        selectedRestTime: newRestTime,
        seconds: newRestTime,
      );
    } else {
      // Se estiver rodando, apenas atualiza a preferência para o próximo reinício
      state = state.copyWith(selectedRestTime: newRestTime);
    }
  }

  void handleAppLifecycleResumed() {
    if (state.isTimerRunning && state.targetExpiryTime != null) {
      final now = DateTime.now();
      final difference = state.targetExpiryTime!.difference(now).inSeconds;
      final int remaining = difference > 0 ? difference : 0;

      // Atualizar notificação com o tempo recalculado
      if (remaining > 0) {
        NotificationService().updateTimerNotification(remaining);
      }

      if (remaining <= 0) {
        pauseTimer();
        state = state.copyWith(seconds: 0);
      } else {
        state = state.copyWith(seconds: remaining);
        // Reiniciar o timer com o tempo sincronizado
        _startPeriodicTimer();
      }
    }
  }
}

class WorkoutTimerState {
  final int seconds;
  final bool isTimerRunning;
  final int selectedRestTime;
  final DateTime? targetExpiryTime;

  WorkoutTimerState({
    required this.seconds,
    required this.isTimerRunning,
    required this.selectedRestTime,
    this.targetExpiryTime,
  });

  factory WorkoutTimerState.initial() {
    return WorkoutTimerState(
      seconds: 0,
      isTimerRunning: false,
      selectedRestTime: 60,
      targetExpiryTime: null,
    );
  }

  WorkoutTimerState copyWith({
    int? seconds,
    bool? isTimerRunning,
    int? selectedRestTime,
    DateTime? targetExpiryTime,
  }) {
    return WorkoutTimerState(
      seconds: seconds ?? this.seconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      selectedRestTime: selectedRestTime ?? this.selectedRestTime,
      targetExpiryTime: targetExpiryTime ?? this.targetExpiryTime,
    );
  }
}

final workoutTimerProvider = NotifierProvider<WorkoutTimerNotifier, WorkoutTimerState>(WorkoutTimerNotifier.new);

final routineProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Observar mudanças no histórico para atualizar o progresso automaticamente
  ref.watch(sessionListProvider);
  return await ref.read(workoutListProvider.notifier).getRoutineProgress();
});
