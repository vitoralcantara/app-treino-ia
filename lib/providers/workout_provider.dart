import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/routine.dart';
import 'backup_provider.dart';

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
    // Tenta fazer backup de forma silenciosa
    ref.read(backupProvider.notifier).uploadBackup();
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
    ref.read(backupProvider.notifier).uploadBackup();
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
    ref.read(backupProvider.notifier).uploadBackup();
  }

  Future<void> addSession(WorkoutSession session) async {
    final db = ref.read(databaseProvider);
    await db.createWorkoutSession(session);
    await _load();
    _triggerCloudBackup();
  }
}

final sessionListProvider = NotifierProvider<SessionListNotifier, List<WorkoutSession>>(SessionListNotifier.new);

final routineProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Observar mudanças no histórico para atualizar o progresso automaticamente
  ref.watch(sessionListProvider);
  return await ref.read(workoutListProvider.notifier).getRoutineProgress();
});
