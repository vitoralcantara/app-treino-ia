import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';

final databaseProvider = Provider((ref) => DatabaseHelper.instance);

class WorkoutListNotifier extends Notifier<List<Workout>> {
  @override
  List<Workout> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    state = await db.getAllWorkouts();
  }

  Future<void> addWorkout(Workout workout) async {
    final db = ref.read(databaseProvider);
    await db.createWorkout(workout);
    await _load();
  }
}

final workoutListProvider = NotifierProvider<WorkoutListNotifier, List<Workout>>(WorkoutListNotifier.new);

final exerciseListProvider = FutureProvider<List<Exercise>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getAllExercises();
});

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
