import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/routine.dart';

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

  Future<void> archiveCurrentRoutine() async {
    final db = ref.read(databaseProvider);
    await db.archiveCurrentRoutine();
    await _load();
  }

  Future<void> activateRoutine(int routineId) async {
    final db = ref.read(databaseProvider);
    await db.activateRoutine(routineId);
    await _load();
  }

  Future<List<Routine>> getArchivedRoutines() async {
    final db = ref.read(databaseProvider);
    return await db.getArchivedRoutines();
  }

  Future<void> addWorkout(Workout workout) async {
    final db = ref.read(databaseProvider);
    await db.createWorkout(workout);
    await _load();
  }

  Future<void> deleteWorkout(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteWorkout(id);
    await _load();
  }

  Future<void> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = ref.read(databaseProvider);
    await db.addExerciseToWorkout(workoutId, exerciseId);
    await _load();
  }

  Future<void> updateExerciseNotesInWorkout(int workoutId, int exerciseId, String notes) async {
    final db = ref.read(databaseProvider);
    await db.updateExerciseNotesInWorkout(workoutId, exerciseId, notes);
    await _load();
  }

  Future<void> removeExerciseFromWorkout(int workoutId, int exerciseId) async {
    final db = ref.read(databaseProvider);
    await db.removeExerciseFromWorkout(workoutId, exerciseId);
    await _load();
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

  Future<void> addExercise(Exercise exercise) async {
    final db = ref.read(databaseProvider);
    await db.createExercise(exercise);
    await _load();
  }

  Future<void> toggleExerciseAvailability(int id, bool isAvailable) async {
    final db = ref.read(databaseProvider);
    await db.toggleExerciseAvailability(id, isAvailable);
    await _load();
  }

  Future<void> deleteExercise(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteExercise(id);
    await _load();
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

  Future<void> addSession(WorkoutSession session) async {
    final db = ref.read(databaseProvider);
    await db.createWorkoutSession(session);
    await _load();
  }
}

final sessionListProvider = NotifierProvider<SessionListNotifier, List<WorkoutSession>>(SessionListNotifier.new);
