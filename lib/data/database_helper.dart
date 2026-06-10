import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // Aumentei a versão para 4
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Adicionado método de atualização
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE exercises ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE exercises ADD COLUMN is_available INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE exercises ADD COLUMN video_url TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE exercises (
        id $idType,
        name $textType,
        category $textTypeNullable,
        instructions $textTypeNullable,
        image_url $textTypeNullable,
        is_available INTEGER DEFAULT 1,
        video_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id $idType,
        name $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id $idType,
        workout_id $intType,
        exercise_id $intType,
        position $intType,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id $idType,
        workout_id $intType,
        workout_name $textType,
        date $textType,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_sets (
        id $idType,
        session_id $intType,
        exercise_id $intType,
        reps $intType,
        weight $doubleType,
        timestamp $textType,
        FOREIGN KEY (session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    // Seed some basic exercises
    await _seedExercises(db);
  }

  Future _seedExercises(Database db) async {
    final basicExercises = [
      {'name': 'Supino Reto', 'category': 'Peito', 'image_url': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Agachamento Livre', 'category': 'Pernas', 'image_url': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Levantamento Terra', 'category': 'Costas', 'image_url': 'https://images.unsplash.com/photo-1603287681836-b174ce5074c2?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Desenvolvimento Militar', 'category': 'Ombros', 'image_url': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Rosca Direta', 'category': 'Bíceps', 'image_url': 'https://images.unsplash.com/photo-1581009137042-c552e485697a?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Tríceps Pulley', 'category': 'Tríceps', 'image_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=400'},
    ];

    for (var exercise in basicExercises) {
      await db.insert('exercises', exercise);
    }
  }

  // --- Exercise Operations ---
  Future<List<Exercise>> getAllExercises() async {
    final db = await instance.database;
    final result = await db.query('exercises', orderBy: 'name');
    return result.map((json) => Exercise.fromJson(json)).toList();
  }

  Future<int> createExercise(Exercise exercise) async {
    final db = await instance.database;
    return await db.insert('exercises', exercise.toJson());
  }

  Future<void> deleteExercise(int id) async {
    final db = await instance.database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await instance.database;
    await db.update(
      'exercises',
      exercise.toJson(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<void> toggleExerciseAvailability(int id, bool isAvailable) async {
    final db = await instance.database;
    await db.update(
      'exercises',
      {'is_available': isAvailable ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Workout Operations ---
  Future<int> createWorkout(Workout workout) async {
    final db = await instance.database;
    final id = await db.insert('workouts', {'name': workout.name});
    
    for (int i = 0; i < workout.exercises.length; i++) {
      final exercise = workout.exercises[i];
      int exerciseId = exercise.id ?? 0;
      
      if (exerciseId == 0) {
         exerciseId = await db.insert('exercises', exercise.toJson());
      }

      await db.insert('workout_exercises', {
        'workout_id': id,
        'exercise_id': exerciseId,
        'position': i,
      });
    }
    return id;
  }

  Future<void> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = await instance.database;
    
    // Get current max position
    final result = await db.rawQuery(
      'SELECT MAX(position) as max_pos FROM workout_exercises WHERE workout_id = ?',
      [workoutId],
    );
    int nextPos = (result.first['max_pos'] as int? ?? -1) + 1;

    await db.insert('workout_exercises', {
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'position': nextPos,
    });
  }

  Future<void> removeExerciseFromWorkout(int workoutId, int exerciseId) async {
    final db = await instance.database;
    await db.delete(
      'workout_exercises',
      where: 'workout_id = ? AND exercise_id = ?',
      whereArgs: [workoutId, exerciseId],
    );
  }

  Future<void> deleteWorkout(int id) async {
    final db = await instance.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    // Cascade delete handles workout_exercises if configured correctly, 
    // but sqflite needs manual delete or pragma foreign_keys = ON
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await instance.database;
    final result = await db.query('workouts');
    
    List<Workout> workouts = [];
    for (var row in result) {
      final id = row['id'] as int;
      final exercisesRows = await db.rawQuery('''
        SELECT e.* FROM exercises e
        JOIN workout_exercises we ON e.id = we.exercise_id
        WHERE we.workout_id = ?
        ORDER BY we.position
      ''', [id]);

      workouts.add(Workout(
        id: id,
        name: row['name'] as String,
        exercises: exercisesRows.map((e) => Exercise.fromJson(e)).toList(),
      ));
    }
    return workouts;
  }

  // --- Session Operations ---
  Future<int> createWorkoutSession(WorkoutSession session) async {
    final db = await instance.database;
    final id = await db.insert('workout_sessions', {
      'workout_id': session.workoutId,
      'workout_name': session.workoutName,
      'date': session.date.toIso8601String(),
    });

    for (var set in session.sets) {
      await db.insert('exercise_sets', {
        'session_id': id,
        'exercise_id': set.exerciseId,
        'reps': set.reps,
        'weight': set.weight,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    return id;
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    final db = await instance.database;
    final result = await db.query('workout_sessions', orderBy: 'date DESC');
    
    List<WorkoutSession> sessions = [];
    for (var row in result) {
      final id = row['id'] as int;
      final setsRows = await db.query('exercise_sets', where: 'session_id = ?', whereArgs: [id]);

      sessions.add(WorkoutSession(
        id: id,
        workoutId: row['workout_id'] as int,
        workoutName: row['workout_name'] as String,
        date: DateTime.parse(row['date'] as String),
        sets: setsRows.map((s) => ExerciseSet.fromJson(s)).toList(),
      ));
    }
    return sessions;
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT ws.date, es.reps, es.weight 
      FROM exercise_sets es
      JOIN workout_sessions ws ON es.session_id = ws.id
      WHERE es.exercise_id = ?
      ORDER BY ws.date DESC, es.id ASC
    ''', [exerciseId]);
    return result;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
